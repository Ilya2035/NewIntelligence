// Pre-analysis settings for eu5.exe (New Intelligence, engine map E2).
//
// Run 4 on: only the analyzers the map needs are switched on (a whitelist), everything else is off.
// Runs 1-3 (2026-11-09) switched heavy analyzers off one by one, and each time the next heavy step failed on this
// 272 MB executable:
//   run 1 - two hours on one core repairing code flow after non-returning calls;
//   run 2 - constant propagation filled the 18 GB heap (99.6 %, 29 full GCs);
//   run 3 - "Create Address Tables" ran out of memory (OutOfMemoryError) after the RTTI step; nothing was saved.
// The map needs: code and functions (entry points, the x64 exception table .pdata, call targets, switch tables),
// references from code and data, the RTTI classes with their virtual tables, and readable (demangled) names.
//@category NewIntelligence
import java.util.Map;
import java.util.Set;
import java.util.TreeMap;

import ghidra.app.script.GhidraScript;

public class NiPreAnalysis extends GhidraScript {

    private static final Set<String> KEEP = Set.of(
        "Disassemble Entry Points",
        "Windows x86 PE Exception Handling",   // .pdata: the start of (almost) every function on x64
        "Subroutine References",               // functions at call targets
        "Reference",
        "Data Reference",
        "Decompiler Switch Analysis",          // code behind switch jumps (ran fine in run 2)
        "Windows x86 PE RTTI Analyzer",        // class names and virtual tables - the map itself
        "Demangler Microsoft",
        "Non-Returning Functions - Known",
        "External Entry References"
    );

    @Override
    protected void run() throws Exception {
        Map<String, String> opts = new TreeMap<>(getCurrentAnalysisOptionsAndValues(currentProgram));
        int on = 0, off = 0;
        for (Map.Entry<String, String> e : opts.entrySet()) {
            String name = e.getKey();
            String value = e.getValue();
            if (name.contains(".") || !("true".equals(value) || "false".equals(value))) {
                continue;   // an option of an analyzer, not an analyzer
            }
            boolean keep = KEEP.contains(name);
            setAnalysisOption(currentProgram, name, keep ? "true" : "false");
            println("NI " + (keep ? "on:  " : "off: ") + name + " (was " + value + ")");
            if (keep) {
                on++;
            } else {
                off++;
            }
        }
        for (String k : KEEP) {
            if (!opts.containsKey(k)) {
                println("NI not present: " + k);
            }
        }
        println("NI whitelist: " + on + " analyzers on, " + off + " off");
    }
}
