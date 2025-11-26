import { WebR } from 'https://webr.r-wasm.org/v0.4.2/webr.mjs';
import { Terminal } from 'https://cdn.jsdelivr.net/npm/xterm@5.3.0/+esm';
import { FitAddon } from 'https://cdn.jsdelivr.net/npm/xterm-addon-fit@0.8.0/+esm';

const statusDiv = document.getElementById('status');
const runButton = document.getElementById('run-button');
const consoleOutput = document.getElementById('console-output');
const plotOutput = document.getElementById('plot-output');

let webR;
let shelter;

// Terminal Setup
const term = new Terminal({
    cursorBlink: true,
    theme: {
        background: '#2d2d2d',
        foreground: '#f8f8f2'
    }
});
const fitAddon = new FitAddon();
term.loadAddon(fitAddon);
term.open(document.getElementById('terminal'));
fitAddon.fit();

let currentLine = '';

term.writeln('\x1b[1;32mWelcome to the bbnetwebasm R Terminal!\x1b[0m');
term.writeln('Type R code and press Enter to run.');
term.write('\r\n> ');

// Simple REPL Input Handler
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
            // Basic filter to avoid control characters breaking things
            if (e >= ' ' && e <= '~') {
                currentLine += e;
                term.write(e);
            }
    }
});

async function runTerminalCommand(code) {
    if (!code.trim()) {
        term.write('> ');
        return;
    }

    if (!webR) {
        term.writeln('\x1b[31mWebR not ready yet.\x1b[0m');
        term.write('> ');
        return;
    }

    try {
        if (!shelter) shelter = await new webR.Shelter();
        
        // Capture output
        const result = await shelter.captureR(code, {
            withAutoprint: true,
            captureStreams: true,
            captureConditions: true
        });

        result.output.forEach(line => {
            if (line.type === 'stdout') {
                term.writeln(line.data);
            } else if (line.type === 'stderr') {
                term.writeln(`\x1b[31m${line.data}\x1b[0m`); // Red for stderr
            }
        });
        
        // Handle plots if any (rudimentary check)
        // In a real console, plots are harder to inline. 
        // We could check if a plot was generated in /tmp/Rtmp... and display it in the plot area.
        
    } catch (e) {
        term.writeln(`\x1b[31mError: ${e.message}\x1b[0m`);
    } finally {
        term.write('> ');
    }
}

async function initWebR() {
    statusDiv.textContent = 'Initializing webR...';

    try {
        webR = new WebR();
        await webR.init();

        statusDiv.textContent = 'Installing bbnetwebasm...';

        // Construct absolute URL for the repo (ensure trailing slash)
        const repoURL = new URL('./repo/', window.location.href).toString();
        console.log('Repo URL:', repoURL);
        const defaultWebRRepo = 'https://webr.r-wasm.org/latest/';
        const bbnetRepos = [repoURL]; // prefer local only to avoid 403s from public repo

        // Quick check: try to fetch PACKAGES for diagnostics (repo/src/contrib/PACKAGES)
        try {
            const pkgResp = await fetch(new URL('src/contrib/PACKAGES', repoURL));
            if (pkgResp.ok) {
                const pkgTxt = await pkgResp.text();
                console.log('PACKAGES contents:\n', pkgTxt);
            } else {
                console.warn('PACKAGES not reachable at', repoURL, pkgResp.status);
                statusDiv.innerHTML += `<br>PACKAGES not reachable at ${repoURL}src/contrib/PACKAGES (status ${pkgResp.status})`;
            }
        } catch (e) {
            console.warn('Error fetching PACKAGES:', e);
        }

        // Install the package and dependencies
        statusDiv.innerHTML += '<br>Installing bbnetwebasm and dependencies...';

        try {
            console.log('Installing bbnetwebasm from repo', repoURL);
            // We provide both our local repo and the public webR repo.
            // This allows webR to find our package locally and resolve dependencies from the public repo.
            await webR.installPackages(['bbnetwebasm'], {
                repos: [repoURL, 'https://repo.r-wasm.org/']
            });
        } catch (err) {
            console.error('Install failed', err);
            statusDiv.innerHTML += '<br>Install failed: ' + err.message;
        }

        // Verify install by attempting to load the package
        try {
            await webR.evalR('library(bbnetwebasm)');
            console.log('bbnetwebasm loaded successfully.');
        } catch (e) {
            console.error('Failed to load bbnetwebasm after install:', e);
            statusDiv.innerHTML += '<br>bbnetwebasm not installed; see console for details.';
            throw e;
        }

        // Load the library
        await webR.evalR('library(bbnetwebasm)');

        statusDiv.textContent = 'Ready!';
        statusDiv.style.backgroundColor = '#d4edda';
        statusDiv.style.color = '#155724';
        runButton.disabled = false;

    } catch (error) {
        console.error('Error initializing webR:', error);
        statusDiv.innerHTML += '<br>Error: ' + error.message;
        statusDiv.style.backgroundColor = '#f8d7da';
        statusDiv.style.color = '#721c24';
    }
}

runButton.onclick = async () => {
    runButton.disabled = true;
    statusDiv.textContent = 'Running demo...';
    consoleOutput.textContent = '';
    plotOutput.innerHTML = '';

    try {
        const shelter = await new webR.Shelter();

        // Run a simple demo: load data and plot
        const code = `
            data(my_network)
            png("/tmp/plot.png", width=800, height=800, res=150)
            bbn.network.diagram(
              bbn.network = my_network, 
              font.size = 0.7,
              arrow.size = 4, 
              arrange = igraph::layout_on_sphere
            )
            dev.off()
            print("Network diagram generated!")
        `;

        const result = await shelter.captureR(code, {
            withAutoprint: true,
            captureStreams: true,
            captureConditions: true
        });

        // Display text output
        result.output.forEach(line => {
            if (line.type === 'stdout' || line.type === 'stderr') {
                consoleOutput.textContent += line.data + '\n';
            }
        });

        // Display plot
        try {
            const plotData = await webR.FS.readFile('/tmp/plot.png');
            const blob = new Blob([plotData], { type: 'image/png' });
            const url = URL.createObjectURL(blob);
            const img = document.createElement('img');
            img.src = url;
            plotOutput.appendChild(img);
        } catch (e) {
            console.log('No plot generated');
        }

        shelter.purge();
        statusDiv.textContent = 'Done!';
    } catch (error) {
        consoleOutput.textContent += '\nError: ' + error.message;
        statusDiv.textContent = 'Error running code';
    } finally {
        runButton.disabled = false;
    }
};

initWebR();
