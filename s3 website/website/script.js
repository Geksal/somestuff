document.addEventListener('DOMContentLoaded', function() {
    const corsTestButton = document.getElementById('cors-test-button');
    const corsResult = document.getElementById('cors-result');
    const statusElement = document.getElementById('status');
    const securityLevel = document.getElementById('security-level');
    const timestampElement = document.getElementById('timestamp');
    
    // Update timestamp every second
    function updateTimestamp() {
        const now = new Date();
        timestampElement.textContent = now.toISOString();
    }
    
    updateTimestamp();
    setInterval(updateTimestamp, 1000);
    
    // Simulate system initialization
    setTimeout(() => {
        statusElement.textContent = "OPERATIONAL";
        statusElement.style.color = "#00ff41";
        
        // Random security level
        const levels = ["ALPHA", "BETA", "GAMMA", "DELTA"];
        securityLevel.textContent = levels[Math.floor(Math.random() * levels.length)];
    }, 1500);
    
    corsTestButton.addEventListener('click', function() {
        // Typing effect for CORS test
        const testingText = "> Initializing CORS protocol test...\n> Establishing secure connection...\n> Processing request...";
        corsResult.innerHTML = "";
        let i = 0;
        
        function typeWriter() {
            if (i < testingText.length) {
                corsResult.innerHTML += testingText.charAt(i);
                i++;
                setTimeout(typeWriter, 15);
            } else {
                // After typing animation, make the actual request
                makeCorsRequest();
            }
        }
        
        typeWriter();
    });
    
    function makeCorsRequest() {
        // Example API endpoint to test CORS
        const testUrl = 'https://jsonplaceholder.typicode.com/todos/1';
        
        setTimeout(() => {
            fetch(testUrl)
                .then(response => {
                    if (!response.ok) {
                        throw new Error('Network response was not ok');
                    }
                    return response.json();
                })
                .then(data => {
                    corsResult.innerHTML = `
                        > CORS TEST STATUS: <span style="color: #00ff41;">SUCCESS</span>
                        > PROTOCOL: HTTPS
                        > ORIGIN: ${new URL(testUrl).origin}
                        > RESPONSE DATA:
                        <pre>${JSON.stringify(data, null, 2)}</pre>
                        > CORS SECURITY VERIFICATION: <span style="color: #00ff41;">PASSED</span>
                    `;
                })
                .catch(error => {
                    corsResult.innerHTML = `
                        > CORS TEST STATUS: <span style="color: #ff0000;">FAILED</span>
                        > ERROR MESSAGE: ${error.message}
                        > PROTOCOL: HTTPS
                        > ORIGIN: ${new URL(testUrl).origin}
                        > RECOMMENDATION: Check CORS configuration and network connectivity
                        > SECURITY STATUS: <span style="color: #ff0000;">WARNING</span>
                    `;
                });
        }, 1500);
    }
    
    // Terminal typing effect for page intro
    const features = document.querySelectorAll('.feature p');
    let delay = 0;
    
    features.forEach(p => {
        p.style.opacity = "0";
        setTimeout(() => {
            p.style.opacity = "1";
            
            // Add typing sound effect
            const audio = new Audio();
            audio.volume = 0.1;
            
        }, delay);
        delay += 300;
    });
    
    // Display hostname information
    const hostname = window.location.hostname;
    const protocol = window.location.protocol;
    
    const footer = document.querySelector('footer');
    const siteInfo = document.createElement('p');
    siteInfo.innerHTML = `ENDPOINT: ${protocol}//${hostname}`;
    footer.appendChild(siteInfo);
    
    // Add interactive terminal cursor blinking to all headings
    const headings = document.querySelectorAll('h1, h2');
    headings.forEach(heading => {
        if (!heading.querySelector('.cursor')) {
            const cursor = document.createElement('span');
            cursor.className = 'cursor';
            heading.appendChild(cursor);
        }
    });
    
    // Add some random "hacker" effect to the page
    function addMatrixEffect() {
        const digits = "0123456789";
        const letters = "ABCDEF";
        const chars = digits + letters;
        
        // Randomly change some text to seem like it's being "hacked"
        setInterval(() => {
            const randElement = document.querySelector('.feature p:not(:first-child)');
            if (randElement && Math.random() > 0.97) {
                const originalText = randElement.textContent;
                let hackedText = "";
                
                for (let i = 0; i < originalText.length; i++) {
                    if (Math.random() > 0.95) {
                        hackedText += chars[Math.floor(Math.random() * chars.length)];
                    } else {
                        hackedText += originalText[i];
                    }
                }
                
                randElement.textContent = hackedText;
                
                // Reset back to original after a short time
                setTimeout(() => {
                    randElement.textContent = originalText;
                }, 200);
            }
        }, 2000);
    }
    
    addMatrixEffect();
});