import { WebR } from 'https://webr.r-wasm.org/v0.4.2/webr.mjs';
import { Terminal } from 'https://cdn.jsdelivr.net/npm/xterm@5.3.0/+esm';
import { FitAddon } from 'https://cdn.jsdelivr.net/npm/xterm-addon-fit@0.8.0/+esm';

const statusDiv = document.getElementById('status');
const runCodeBtn = document.getElementById('run-code-btn');
const plotOutput = document.getElementById('plot-output');

let webR;
let shelter;
let editor;

// --- Layout & Terminal Setup ---

// Split Panes
Split(['#source-pane', '#console-pane'], {
    sizes: [50, 50],
    minSize: 200,
    gutterSize: 10,
    onDragEnd: () => fitAddon.fit()
});

// Terminal
const term = new Terminal({
    cursorBlink: true,
    theme: {
        background: '#2d2d2d',
        foreground: '#f8f8f2'
    },
    fontSize: 14,
    fontFamily: 'Menlo, Monaco, "Courier New", monospace'
});
const fitAddon = new FitAddon();
term.loadAddon(fitAddon);
term.open(document.getElementById('terminal'));
fitAddon.fit();

// Resize terminal on window resize
window.addEventListener('resize', () => fitAddon.fit());

let currentLine = '';

term.writeln('\x1b[1;34mR WebConsole initialized.\x1b[0m');
term.write('\r\n> ');

// Terminal Input Handler
term.onData(e => {
    switch (e) {
        case '\r': // Enter
            term.write('\r\n');
            runTerminalCommand(currentLine);
            currentLine = '';
            break;
        case '\u007F': // Backspace
            if (currentLine.length > 0) {
                term.write('\b \b');
                currentLine = currentLine.slice(0, -1);
            }
            break;
        default: // Typing
            if (e >= ' ' && e <= '~') {
                currentLine += e;
                term.write(e);
            }
    }
});

// --- Monaco Editor Setup ---

require.config({ paths: { 'vs': 'https://cdnjs.cloudflare.com/ajax/libs/monaco-editor/0.44.0/min/vs' }});

require(['vs/editor/editor.main'], function() {
    editor = monaco.editor.create(document.getElementById('monaco-editor'), {
        value: [
            "# --- bbnetwebasm Demo (based on Vignette) ---",
            "",
            "# 1. Setup",
            "library(bbnetwebasm)",
            "",
            "# 2. Importing Data",
            "# The package includes example datasets for a Rocky Shore model.",
            "data(\"my_BBN\")",
            "# print(head(my_BBN))",
            "",
            "# Load scenarios (Dogwhelk removal, Winkle addition, Combined)",
            "data(\"dogwhelk\", \"winkle\", \"combined\")",
            "# print(head(dogwhelk))",
            "",
            "# 3. Running a Predictive Model (bbn.predict)",
            "# Run prediction for dogwhelk removal",
            "# (figure=0 to suppress PDF output for console view)",
            "print('Running prediction for dogwhelk removal...')",
            "bbn.predict(bbn.model = my_BBN, priors1 = dogwhelk, figure = 0)",
            "",
            "# Run multiple scenarios with bootstrapping",
            "print('Running bootstrapped predictions (100 iterations)...')",
            "bbn.predict(",
            "  bbn.model = my_BBN, ",
            "  priors1 = dogwhelk, ",
            "  priors2 = winkle, ",
            "  priors3 = combined, ",
            "  figure = 0, ",
            "  boot_max = 100, ",
            "  values = 0, ",
            "  font.size = 7",
            ")",
            "",
            "# 4. Visualising Changes Over Time (bbn.timeseries)",
            "# Visualize the 'combined' scenario over 6 timesteps",
            "print('Generating Time Series plot...')",
            "bbn.timeseries(bbn.model = my_BBN, priors1 = combined, timesteps = 6, disturbance = 2)",
            "",
            "# 5. Visualising Network Changes (bbn.visualise)",
            "# Visualize network state at each timestep",
            "# (Note: This produces multiple plots, only the last might show in this simple viewer)",
            "print('Generating Network Visualization...')",
            "bbn.visualise(",
            "  bbn.model = my_BBN, ",
            "  priors1 = combined, ",
            "  timesteps = 5, ",
            "  disturbance = 2, ",
            "  threshold = 0.05, ",
            "  font.size = 0.7, ",
            "  arrow.size = 4",
            ")",
            "",
            "# 6. Sensitivity Analysis (bbn.sensitivity)",
            "print('Running Sensitivity Analysis...')",
            "bbn.sensitivity(bbn.model = my_BBN, boot_max = 50, 'Limpet', 'Green Algae')",
            "",
            "# 7. Network Diagram (bbn.network.diagram)",
            "data(\"my_network\")",
            "print('Drawing Network Diagram...')",
            "bbn.network.diagram(",
            "  bbn.network = my_network, ",
            "  font.size = 0.7, ",
            "  arrow.size = 4, ",
            "  arrange = igraph::layout_on_sphere",
            ")",
            "",
            "print('Demo Complete!')"
        ].join('\n'),
        language: 'r',
        theme: 'vs-light',
        automaticLayout: true,
        minimap: { enabled: false }
    });

    // Ctrl+Enter to run
    editor.addCommand(monaco.KeyMod.CtrlCmd | monaco.KeyCode.Enter, runEditorCode);
});

// --- Execution Logic ---

async function runTerminalCommand(code) {
    if (!code.trim()) {
        term.write('> ');
        return;
    }
    await executeR(code);
    term.write('> ');
}

async function runEditorCode() {
    if (!editor || !webR) return;
    
    // Get selected text or full text
    const selection = editor.getModel().getValueInRange(editor.getSelection());
    const code = selection || editor.getValue();
    
    if (!code.trim()) return;

    // Echo to terminal
    term.writeln(`\x1b[32m> [Run] Executing code...\x1b[0m`);
    
    await executeR(code);
    term.write('> ');
}

async function executeR(code) {
    if (!webR) {
        term.writeln('\x1b[31mWebR not ready.\x1b[0m');
        return;
    }

    try {
        if (!shelter) shelter = await new webR.Shelter();

        term.writeln('\x1b[90m> [Debug] Executing wrapped code...\x1b[0m');

        // Wrap user code to capture plot
        const fullCode = `
            png("/tmp/plot.png", width=800, height=600, res=150)
            tryCatch({
                ${code}
            }, finally = {
                dev.off()
            })
        `;

        // Execute User Code
        const result = await shelter.captureR(fullCode, {
            withAutoprint: true,
            captureStreams: true,
            captureConditions: true
        });

        result.output.forEach(line => {
            if (line.type === 'stdout') {
                term.writeln(line.data);
            } else if (line.type === 'stderr') {
                term.writeln(`\x1b[31m${line.data}\x1b[0m`);
            }
        });

        // Handle Plot
        try {
            const plotData = await webR.FS.readFile('/tmp/plot.png');
            term.writeln(`\x1b[90m> [Debug] Plot file found. Size: ${plotData.length} bytes.\x1b[0m`);
            
            // Check if it's a valid non-empty image (PNG header usually)
            if (plotData.length > 0) {
                const blob = new Blob([plotData], { type: 'image/png' });
                const url = URL.createObjectURL(blob);
                
                plotOutput.innerHTML = ''; 
                const img = document.createElement('img');
                img.src = url;
                plotOutput.appendChild(img);
                plotOutput.style.display = 'block'; // Ensure it's visible
                term.writeln(`\x1b[90m> [Debug] Plot image URL: ${url}\x1b[0m`);
            }
            // Cleanup? Maybe keep for history or debug.
        } catch (e) {
            // No plot file created (normal for non-plotting code)
            term.writeln('\x1b[90m> [Debug] No plot generated.\x1b[0m');
        }

    } catch (e) {
        term.writeln(`\x1b[31mError: ${e.message}\x1b[0m`);
        // Try to close device if code failed
        try { await webR.evalR('dev.off()'); } catch (e2) {} 
    } finally {
        // shelter.purge(); 
    }
}

runCodeBtn.onclick = runEditorCode;

// --- WebR Initialization ---

async function initWebR() {
    statusDiv.textContent = 'Initializing webR...';

    try {
        webR = new WebR();
        await webR.init();

        statusDiv.textContent = 'Installing bbnetwebasm...';

        const repoURL = new URL('./repo/', window.location.href).toString();
        
        await webR.installPackages(['bbnetwebasm'], {
            repos: [repoURL, 'https://repo.r-wasm.org/']
        });

        // Load the library
        await webR.evalR('library(bbnetwebasm)');

        statusDiv.textContent = 'Ready';
        statusDiv.style.backgroundColor = '#d4edda';
        statusDiv.style.color = '#155724';
        runCodeBtn.disabled = false;
        term.writeln('\x1b[32mWebR Ready! bbnetwebasm loaded.\x1b[0m');
        term.write('> ');

    } catch (error) {
        console.error('Error initializing webR:', error);
        statusDiv.innerHTML = 'Error: ' + error.message;
        statusDiv.style.backgroundColor = '#f8d7da';
        statusDiv.style.color = '#721c24';
        term.writeln(`\x1b[31mWebR Init Failed: ${error.message}\x1b[0m`);
    }
}

initWebR();
