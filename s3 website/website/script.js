// Wait for DOM to fully load
document.addEventListener('DOMContentLoaded', function() {
    // Matrix background effect
    const canvas = document.getElementById('matrix-canvas');
    const ctx = canvas.getContext('2d');

    // Set canvas dimensions
    canvas.width = window.innerWidth;
    canvas.height = window.innerHeight;

    // Characters to be used in the matrix rain
    const characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789$+=?@#&%';
    const fontSize = 14;
    const columns = Math.floor(canvas.width / fontSize);
    
    // Array to store the y position of each column
    const drops = [];
    for (let i = 0; i < columns; i++) {
        drops[i] = Math.random() * -100;
    }

    // Drawing the matrix rain
    function drawMatrix() {
        // Semi-transparent black to create fade effect
        ctx.fillStyle = 'rgba(0, 0, 0, 0.05)';
        ctx.fillRect(0, 0, canvas.width, canvas.height);
        
        ctx.fillStyle = '#00ff41'; // Matrix green
        ctx.font = `${fontSize}px monospace`;
        
        // Loop through each drop
        for (let i = 0; i < drops.length; i++) {
            // Get random character
            const char = characters.charAt(Math.floor(Math.random() * characters.length));
            
            // Draw the character
            ctx.fillText(char, i * fontSize, drops[i] * fontSize);
            
            // Move the drop down
            if (drops[i] * fontSize > canvas.height && Math.random() > 0.975) {
                drops[i] = 0;
            }
            drops[i]++;
        }
    }
    
    // Run the matrix animation
    setInterval(drawMatrix, 50);

    // Resize handler for canvas
    window.addEventListener('resize', function() {
        canvas.width = window.innerWidth;
        canvas.height = window.innerHeight;
    });

    // Header scroll effect
    const header = document.querySelector('header');
    window.addEventListener('scroll', function() {
        if (window.scrollY > 50) {
            header.classList.add('scrolled');
        } else {
            header.classList.remove('scrolled');
        }
    });

    // Typewriter effect
    const textElement = document.getElementById('typewriter-text');
    const textList = ['Mindset.', 'Lifestyle.', 'Necessity.', 'Responsibility.'];
    let textIndex = 0;
    let charIndex = 0;
    let isDeleting = false;
    let typingSpeed = 100;

    function typeText() {
        const currentText = textList[textIndex];
        
        if (isDeleting) {
            textElement.textContent = currentText.substring(0, charIndex - 1);
            charIndex--;
            typingSpeed = 50;
        } else {
            textElement.textContent = currentText.substring(0, charIndex + 1);
            charIndex++;
            typingSpeed = 150;
        }
        
        if (!isDeleting && charIndex === currentText.length) {
            isDeleting = true;
            typingSpeed = 1500; // Pause at the end
        } else if (isDeleting && charIndex === 0) {
            isDeleting = false;
            textIndex = (textIndex + 1) % textList.length;
            typingSpeed = 500; // Pause before typing next word
        }
        
        setTimeout(typeText, typingSpeed);
    }
    
    // Start the typewriter effect
    typeText();

    // Password strength checker
    const passwordField = document.getElementById('password-field');
    const checkBtn = document.getElementById('check-btn');
    const strengthMeter = document.getElementById('strength-meter');
    const strengthText = document.getElementById('strength-text');
    
    checkBtn.addEventListener('click', function() {
        const password = passwordField.value;
        const strength = checkPasswordStrength(password);
        
        // Update the meter
        strengthMeter.style.width = `${strength.score * 25}%`;
        strengthMeter.style.backgroundColor = strength.color;
        strengthText.textContent = strength.message;
        
        // Add animation effect
        strengthMeter.style.transition = 'width 0.5s ease, background-color 0.5s ease';
    });
    
    function checkPasswordStrength(password) {
        let score = 0;
        let message = '';
        let color = '';
        
        if (password.length === 0) {
            message = 'No password entered';
            color = '#777';
            return { score, message, color };
        }
        
        // Check length
        if (password.length < 6) {
            score = 1;
            message = 'Too short - Easy to crack';
            color = '#ff4d4d';
        } else if (password.length < 10) {
            score = 2;
            message = 'Could be stronger';
            color = '#ffa64d';
        } else {
            score = 3;
            message = 'Good length';
            color = '#4da6ff';
        }
        
        // Check for numbers
        if (/\d/.test(password)) {
            score += 0.5;
        }
        
        // Check for special characters
        if (/[!@#$%^&*(),.?":{}|<>]/.test(password)) {
            score += 0.5;
        }
        
        // Check for uppercase and lowercase
        if (/[A-Z]/.test(password) && /[a-z]/.test(password)) {
            score += 0.5;
        }
        
        // Final score adjustment
        if (score > 4) {
            score = 4;
            message = 'Very strong password';
            color = '#2ecc71';
        } else if (score > 3) {
            message = 'Strong password';
            color = '#2ecc71';
        } else if (score > 2) {
            message = 'Medium strength password';
            color = '#f39c12';
        }
        
        return { score, message, color };
    }

    // Caesar cipher slider
    const cipherSlider = document.getElementById('cipher-slider');
    const sliderValue = document.getElementById('slider-value');
    const decryptedResult = document.getElementById('decrypted-result');
    const encryptedMessage = document.getElementById('encrypted-message');
    
    // Original encrypted message
    const originalMessage = "Fhpxgt bl max uxlm ixbyx hy frmr!";
    
    // Update slider value display and decrypt message
    cipherSlider.addEventListener('input', function() {
        const shift = parseInt(this.value);
        sliderValue.textContent = shift;
        
        decryptedResult.textContent = caesarCipher(originalMessage, shift);
        
        // Check if the correct solution is found (shift of 7)
        if (shift === 7) {
            decryptedResult.style.color = '#2ecc71';
            decryptedResult.style.fontWeight = 'bold';
        } else {
            decryptedResult.style.color = '';
            decryptedResult.style.fontWeight = '';
        }
    });
    
    // Caesar cipher algorithm
    function caesarCipher(str, shift) {
        return str.replace(/[a-zA-Z]/g, function(char) {
            // Get the character code
            const code = char.charCodeAt(0);
            
            // Determine if uppercase or lowercase
            const base = code >= 65 && code <= 90 ? 65 : 97;
            
            // Perform the shift
            return String.fromCharCode(((code - base + shift) % 26) + base);
        });
    }

    // Modal functionality
    const decodeBtn = document.getElementById('decode-btn');
    const modal = document.getElementById('decode-modal');
    const closeModal = document.getElementById('close-modal');
    const terminalOutput = document.getElementById('terminal-output');
    
    decodeBtn.addEventListener('click', function() {
        modal.style.display = 'flex';
        
        // Simulate terminal typing
        let i = 5;
        const messages = [
            "> Access granted...",
            "> Decoding special message...",
            "> Message: 'Security is not just about tools, but about awareness and education.'",
            "> Remember: The strongest security system can be compromised by a single weak human link.",
            "> Stay vigilant. Stay secure."
        ];
        
        function typeMessage() {
            if (i < messages.length) {
                const p = document.createElement('p');
                p.textContent = messages[i];
                terminalOutput.appendChild(p);
                i++;
                setTimeout(typeMessage, 1500);
            }
        }
        
        typeMessage();
    });
    
    closeModal.addEventListener('click', function() {
        modal.style.display = 'none';
    });
    
    // Close modal when clicking outside
    window.addEventListener('click', function(event) {
        if (event.target === modal) {
            modal.style.display = 'none';
        }
    });
    
    // Interactive hover effects for cards
    const cards = document.querySelectorAll('.card');
    
    cards.forEach(card => {
        card.addEventListener('mouseenter', function() {
            this.style.transform = 'translateY(-10px)';
        });
        
        card.addEventListener('mouseleave', function() {
            this.style.transform = '';
        });
    });
});