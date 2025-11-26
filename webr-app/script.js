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
            "# Welcome to bbnetwebasm IDE",
            "library(bbnetwebasm)",
            "data(my_network)",
            "",
            "# Plot the network",
            "bbn.network.diagram(",
            "  bbn.network = my_network,",
            "  font.size = 0.7,",
            "  arrow.size = 4,",
            "  arrange = igraph::layout_on_sphere",
            ")",
            "",
            "# Check console for output"
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

        // Open graphics device
        term.writeln('\x1b[90m> [Debug] Opening graphics device...\x1b[0m');
        await webR.evalR('png("/tmp/plot.png", width=800, height=600, res=150)');

        // Execute User Code
        const result = await shelter.captureR(code, {
            withAutoprint: true,
            captureStreams: true,
            captureConditions: true
        });

        // Close device to flush plot
        await webR.evalR('dev.off()');
        term.writeln('\x1b[90m> [Debug] Device closed.\x1b[0m');

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
                plotOutput.style.display = 'flex'; // Force visible
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
