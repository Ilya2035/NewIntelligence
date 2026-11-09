// Engine map queries for eu5.exe (New Intelligence, E2 -> E3).
// Runs against the ALREADY ANALYSED project (no new analysis):
//   analyzeHeadless <work> eu5 -process eu5_26377361.exe -noanalysis -readOnly
//       -scriptPath <dir> -postScript NiEngineMap.java <topic|all> <output file>
// (extender/engine/ghidra/query.ps1 does exactly this.)
//
// For every topic it writes:
//   1. each name string the engine reads (define names, modifier types, on_actions) - where it lies, which functions
//      refer to it (directly, or through one data table), and who calls those functions;
//   2. each class whose RTTI name matches the topic - its virtual table and the functions in it.
// Addresses are only for orientation inside this one build; the engine patches themselves must be found again by byte
// patterns (EXTENDER_FEASIBILITY.md, E3).
//@category NewIntelligence
import java.io.File;
import java.io.PrintWriter;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeSet;

import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.program.model.mem.Memory;
import ghidra.program.model.mem.MemoryBlock;
import ghidra.program.model.symbol.Reference;
import ghidra.program.model.symbol.ReferenceIterator;
import ghidra.program.model.symbol.Symbol;
import ghidra.program.model.symbol.SymbolIterator;

public class NiEngineMap extends GhidraScript {

    /** topic -> { strings to find, RTTI class-name fragments } */
    private static final Map<String, String[][]> TOPICS = new LinkedHashMap<>();
    static {
        // "People, garrisons and the city guard" (GEOPOLICY_V012_PLAN.md 4a; author 2026-11-09: engine only)
        TOPICS.put("control", new String[][] {
            { "MONTHLY_CONTROL_MAXIMUM_VALUE", "MILITARY_CONTROL_FLOOR", "PROXIMITY_DESIRE_PER_MAX_CONTROL",
              "LOW_CONTROL_THRESHOLD_FOR_BEST_TAX", "local_monthly_control", "local_max_control",
              "local_monthly_control_decline", "global_monthly_control", "global_max_control" },
            { "ChangeControl", "LocalControl", "MaxControl", "AverageControl" } });
        TOPICS.put("garrison", new String[][] {
            { "GARRISON_AFTER_OCCUPATION", "GARRISON_MANPOWER_LOSS_IMPACT", "SIEGE_GARRISON_SURRENDER_THRESHOLD",
              "local_garrison_size", "local_garrison_growth", "global_garrison_growth", "global_garrison_size_modifier" },
            { "Garrison", "HasFort", "NumForts", "FortLimit" } });
        TOPICS.put("occupation", new String[][] {
            { "on_location_occupied", "on_siege_won", "on_siege_lost", "occupation_time" },
            { "Occupation", "ChangeLocationController" } });
        TOPICS.put("separatism", new String[][] {
            { "local_separatism", "global_separatism", "local_unrest", "REBEL_FORT_LOYALTY_BASE",
              "REBEL_FORT_LOYALTY_CULTURE_BONUS", "REBEL_LACK_OF_CONTROL_FACTOR", "REBEL_NON_INTEGRATED_FACTOR" },
            { "Rebel", "Integration", "Integrat" } });
        TOPICS.put("maintenance", new String[][] {
            { "last_months_fort_maintenance", "last_months_army_maintenance", "last_months_building_maintenance",
              "on_maintenance_changed", "set_maintenance", "lock_maintenance", "AI_MAINTENANCE_BUDGET_RATIO" },
            { "Maintenance" } });
        // E4: the AI of armies and sieges
        TOPICS.put("ai", new String[][] {
            { "AI_STRAIT_DISTANCE_TO_ENEMY_THRESHOLD", "OUTNUMBERED_SEPARABLE_WEIGHT" },
            { "CAi" } });
    }

    private static final int MAX_REFS = 40;
    private static final int MAX_CALLERS = 12;
    private static final int MAX_VTABLE_SLOTS = 48;

    private PrintWriter out;

    @Override
    protected void run() throws Exception {
        String[] args = getScriptArgs();
        String topic = args.length > 0 ? args[0] : "all";
        File file = new File(args.length > 1 ? args[1] : "ni_engine_map_" + topic + ".txt");
        out = new PrintWriter(file, StandardCharsets.UTF_8);
        try {
            out.println("# NiEngineMap " + currentProgram.getName() + " topic=" + topic);
            for (Map.Entry<String, String[][]> t : TOPICS.entrySet()) {
                if (!topic.equals("all") && !topic.equals(t.getKey())) {
                    continue;
                }
                out.println();
                out.println("## topic " + t.getKey());
                for (String s : t.getValue()[0]) {
                    monitor.checkCancelled();
                    mapString(s);
                }
                mapClasses(t.getValue()[1]);
                out.flush();
            }
        } finally {
            out.close();
        }
        println("NI map written: " + file.getAbsolutePath());
    }

    // ---- 1. strings -------------------------------------------------------------------------------------------

    private void mapString(String s) throws Exception {
        byte[] raw = s.getBytes(StandardCharsets.US_ASCII);
        // with the terminating zero, so that "local_unrest" does not also match "local_unrest_x"
        byte[] pattern = new byte[raw.length + 1];
        System.arraycopy(raw, 0, pattern, 0, raw.length);
        Memory mem = currentProgram.getMemory();
        Address at = mem.getMinAddress();
        int hits = 0;
        while (at != null) {
            Address found = mem.findBytes(at, pattern, null, true, monitor);
            if (found == null) {
                break;
            }
            hits++;
            // the string must start there (not be the tail of a longer name)
            boolean starts = true;
            try {
                byte before = mem.getByte(found.subtract(1));
                starts = !(Character.isLetterOrDigit(before) || before == '_');
            } catch (Exception e) {
                // start of a block
            }
            if (starts) {
                out.println("string \"" + s + "\" at " + found);
                listRefs(found, "  ", true);
            }
            at = found.next();
        }
        if (hits == 0) {
            out.println("string \"" + s + "\" NOT FOUND");
        }
    }

    /** References to addr; code refs give the function, data refs are followed one hop (name tables). */
    private void listRefs(Address addr, String indent, boolean followData) throws Exception {
        ReferenceIterator it = currentProgram.getReferenceManager().getReferencesTo(addr);
        int n = 0;
        Set<String> seenFunctions = new TreeSet<>();
        while (it.hasNext() && n < MAX_REFS) {
            Reference r = it.next();
            Address from = r.getFromAddress();
            Function f = getFunctionContaining(from);
            MemoryBlock b = currentProgram.getMemory().getBlock(from);
            String block = b == null ? "?" : b.getName();
            n++;
            if (f != null) {
                String key = f.getEntryPoint().toString();
                if (seenFunctions.add(key)) {
                    out.println(indent + "used in " + f.getName(true) + " @" + f.getEntryPoint() + " (" + r.getReferenceType()
                        + " from " + from + ", " + f.getBody().getNumAddresses() + " bytes)");
                    listCallers(f, indent + "    ");
                }
            } else {
                out.println(indent + "data ref from " + from + " [" + block + "]");
                if (followData) {
                    listRefs(from, indent + "    ", false);
                }
            }
        }
        if (n == 0) {
            out.println(indent + "(no references)");
        }
    }

    private void listCallers(Function f, String indent) throws Exception {
        Set<Function> callers = f.getCallingFunctions(monitor);
        int n = 0;
        for (Function c : callers) {
            if (n++ >= MAX_CALLERS) {
                out.println(indent + "... " + (callers.size() - MAX_CALLERS) + " more callers");
                break;
            }
            out.println(indent + "called by " + c.getName(true) + " @" + c.getEntryPoint());
        }
    }

    // ---- 2. RTTI classes ----------------------------------------------------------------------------------------

    private void mapClasses(String[] fragments) throws Exception {
        SymbolIterator it = currentProgram.getSymbolTable().getSymbols("vftable");
        List<Symbol> matched = new ArrayList<>();
        while (it.hasNext()) {
            Symbol s = it.next();
            String cls = s.getParentNamespace().getName(true);
            for (String frag : fragments) {
                if (cls.contains(frag)) {
                    matched.add(s);
                    break;
                }
            }
        }
        out.println("classes matching " + String.join("|", fragments) + ": " + matched.size());
        Memory mem = currentProgram.getMemory();
        for (Symbol s : matched) {
            monitor.checkCancelled();
            out.println("class " + s.getParentNamespace().getName(true) + " vftable @" + s.getAddress());
            Address slot = s.getAddress();
            for (int i = 0; i < MAX_VTABLE_SLOTS; i++) {
                long target;
                try {
                    target = mem.getLong(slot);
                } catch (Exception e) {
                    break;
                }
                Address t = toAddr(target);
                MemoryBlock b = t == null ? null : mem.getBlock(t);
                if (b == null || !b.isExecute()) {
                    break;   // the table ended
                }
                Function f = getFunctionAt(t);
                out.println("  [" + i + "] " + (f == null ? "code @" + t : f.getName(true) + " @" + t
                    + " (" + f.getBody().getNumAddresses() + " bytes)"));
                slot = slot.add(8);
            }
        }
    }
}
