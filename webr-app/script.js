import { WebR } from 'https://webr.r-wasm.org/v0.4.2/webr.mjs';

const statusDiv = document.getElementById('status');
const runButton = document.getElementById('run-button');
const consoleOutput = document.getElementById('console-output');
const plotOutput = document.getElementById('plot-output');

let webR;

async function initWebR() {
    statusDiv.textContent = 'Initializing webR...';

    try {
        webR = new WebR();
        await webR.init();

        statusDiv.textContent = 'Installing bbnetwebasm...';

        // Construct absolute URL for the repo
        // We assume the repo is at ./repo/ relative to index.html
        const repoURL = new URL('repo/', window.location.href).toString();
        console.log('Repo URL:', repoURL);

        // Probe for PACKAGES file to debug path issues
        const rVersions = ['4.3', '4.4', '4.5'];
        for (const version of rVersions) {
            const probeURL = new URL(`bin/emscripten/contrib/${version}/PACKAGES`, repoURL).toString();
            console.log(`Probing ${probeURL}...`);
            statusDiv.innerHTML += `<br>Probing ${version}...`;
            try {
                const response = await fetch(probeURL, { method: 'HEAD' });
                console.log(`Probe ${version}: ${response.status} ${response.statusText}`);
                statusDiv.innerHTML += ` ${response.status} ${response.statusText}`;
                if (response.ok) {
                    statusDiv.innerHTML += ` (Found!)`;
                }
            } catch (e) {
                console.log(`Probe ${version} failed:`, e);
                statusDiv.innerHTML += ` Failed: ${e.message}`;
            }
        }

        // Install igraph manually (since we removed it from DESCRIPTION to fix build)
        statusDiv.innerHTML += '<br>Installing igraph...';
        await webR.installPackages(['igraph']);

        // Install the package
        statusDiv.innerHTML += '<br>Installing bbnetwebasm...';
        await webR.installPackages(['bbnetwebasm'], {
            repos: [repoURL]
        });

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
              arrange = "dot", 
              palette = "classic"
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
