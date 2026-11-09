// Pre-analysis settings for eu5.exe (New Intelligence, engine map E2).
// Keeps the RTTI analyzer (class names are our map), turns off the slowest analyzers and any PDB
// lookup (there is no public eu5.pdb), and prints every analyzer with its value to the script log.
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
    };

    @Override
    protected void run() throws Exception {
        Map<String, String> opts = new TreeMap<>(getCurrentAnalysisOptionsAndValues(currentProgram));
        for (String name : OFF) {
            if (opts.containsKey(name)) {
                setAnalysisOption(currentProgram, name, "false");
                println("NI off: " + name);
            } else {
                println("NI not present: " + name);
            }
        }
        for (Map.Entry<String, String> e : opts.entrySet()) {
            if (!e.getKey().contains(".")) {
                println("NI analyzer " + e.getKey() + " = " + e.getValue());
            }
        }
    }
}
