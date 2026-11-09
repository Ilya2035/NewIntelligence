// Pre-analysis settings for eu5.exe (New Intelligence, engine map E2).
// Keeps the RTTI analyzer (class names are our map), turns off the slowest analyzers and any PDB
// lookup (there is no public eu5.pdb), and prints every analyzer with its value to the script log.
//
// Run 1 (2026-11-09) spent more than two hours on one core in "Non-Returning Functions - Discovered",
// repairing the code flow after calls that never return (ClearFlowAndRepairCmd). That repair is not
// needed for our map (classes, virtual tables, callers), so run 2 switches it off: only the repair
// option when it exists, otherwise the whole analyzer. Run 3 also drops constant propagation (see OFF).
//@category NewIntelligence
import java.util.Map;
import java.util.TreeMap;

import ghidra.app.script.GhidraScript;

public class NiPreAnalysis extends GhidraScript {

    private static final String[] OFF = {
        "Decompiler Parameter ID",       // runs the decompiler on every function: days on a 190 MB .text
        "PDB Universal",                 // no PDB exists; avoid symbol-server lookups
        "PDB MSDIA",
        "Aggressive Instruction Finder", // guesses code in gaps, slow and noisy
        // Run 2 (26 threads, 18 GB): constant propagation filled the heap to 99.6 % (29 full GCs) in 30 minutes. It adds
        // references to addresses computed in registers; the x64 code reaches its strings and virtual tables through
        // RIP-relative operands, which the disassembler already turns into references, so the map does without it.
        "x86 Constant Reference Analyzer",
    };

    private static final String NO_RETURN = "Non-Returning Functions - Discovered";

    @Override
    protected void run() throws Exception {
        Map<String, String> opts = new TreeMap<>(getCurrentAnalysisOptionsAndValues(currentProgram));
        for (String name : OFF) {
            switchOff(opts, name);
        }
        String repair = null;
        for (String key : opts.keySet()) {
            if (key.startsWith(NO_RETURN + ".")) {
                println("NI option " + key + " = " + opts.get(key));
                if (key.toLowerCase().contains("repair")) {
                    repair = key;
                }
            }
        }
        if (repair != null) {
            switchOff(opts, repair);
        } else {
            switchOff(opts, NO_RETURN);
        }
        for (Map.Entry<String, String> e : opts.entrySet()) {
            if (!e.getKey().contains(".")) {
                println("NI analyzer " + e.getKey() + " = " + e.getValue());
            }
        }
    }

    private void switchOff(Map<String, String> opts, String name) {
        if (opts.containsKey(name)) {
            setAnalysisOption(currentProgram, name, "false");
            println("NI off: " + name);
        } else {
            println("NI not present: " + name);
        }
    }
}
