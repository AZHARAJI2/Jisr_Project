/**
 * Crisis Bridge — Interactive UI Script
 * Handles animations, interactions, and dynamic behavior
 */

document.addEventListener('DOMContentLoaded', () => {

    // ===== Bottom Navigation =====
    const navItems = document.querySelectorAll('.nav-item');

    navItems.forEach(item => {
        item.addEventListener('click', () => {
            navItems.forEach(nav => nav.classList.remove('active'));
            item.classList.add('active');

            // Haptic-like feedback (scale bounce)
            item.style.transform = 'scale(0.9)';
            setTimeout(() => {
                item.style.transform = 'scale(1)';
            }, 120);
        });
    });

    // ===== Notification Bell Click =====
    const bell = document.getElementById('notificationBell');
    if (bell) {
        bell.addEventListener('click', () => {
            bell.style.transform = 'rotate(15deg)';
            setTimeout(() => bell.style.transform = 'rotate(-15deg)', 100);
            setTimeout(() => bell.style.transform = 'rotate(10deg)', 200);
            setTimeout(() => bell.style.transform = 'rotate(-5deg)', 300);
            setTimeout(() => bell.style.transform = 'rotate(0)', 400);

            // Hide notification dot on click
            const dot = bell.querySelector('.notification-dot');
            if (dot) {
                dot.style.transition = 'opacity 0.3s, transform 0.3s';
                dot.style.opacity = '0';
                dot.style.transform = 'scale(0)';
            }
        });
    }

    // ===== FAB Button Interaction =====
    const fabButton = document.getElementById('fabButton');
    if (fabButton) {
        fabButton.addEventListener('click', () => {
            // Rotate icon on click
            fabButton.style.animation = 'none';
            fabButton.style.transform = 'rotate(180deg) scale(1.1)';
            setTimeout(() => {
                fabButton.style.transform = 'rotate(360deg) scale(1)';
            }, 300);
            setTimeout(() => {
                fabButton.style.animation = '';
                fabButton.style.transform = '';
            }, 700);
        });
    }

    // ===== Action Buttons Ripple Effect =====
    const actionButtons = document.querySelectorAll('.action-btn');
    actionButtons.forEach(btn => {
        btn.addEventListener('click', (e) => {
            // Create ripple
            const ripple = document.createElement('span');
            ripple.style.cssText = `
                position: absolute;
                border-radius: 50%;
                background: rgba(0, 242, 255, 0.15);
                width: 80px;
                height: 80px;
                transform: scale(0);
                animation: rippleEffect 0.6s ease-out;
                pointer-events: none;
                left: 50%;
                top: 50%;
                margin-left: -40px;
                margin-top: -40px;
            `;
            btn.style.position = 'relative';
            btn.style.overflow = 'hidden';
            btn.appendChild(ripple);
            setTimeout(() => ripple.remove(), 600);
        });
    });

    // Add ripple keyframe dynamically
    const styleSheet = document.createElement('style');
    styleSheet.textContent = `
        @keyframes rippleEffect {
            to { transform: scale(2.5); opacity: 0; }
        }
    `;
    document.head.appendChild(styleSheet);

    // ===== Network Node Tooltips =====
    const networkNodes = document.querySelectorAll('.network-node');
    const nodeData = {
        'London': { status: 'Active', latency: '12ms', connections: 4 },
        'NY': { status: 'Active', latency: '8ms', connections: 3 },
        'Tokyo': { status: 'Active', latency: '22ms', connections: 3 },
        'Lagos': { status: 'Active', latency: '45ms', connections: 3 },
        'Seoul': { status: 'Active', latency: '18ms', connections: 2 }
    };

    networkNodes.forEach(node => {
        node.addEventListener('mouseenter', () => {
            const city = node.getAttribute('data-city');
            const inner = node.querySelector('.node-inner');
            if (inner) {
                inner.style.transition = 'r 0.2s';
            }
        });

        node.addEventListener('click', () => {
            const city = node.getAttribute('data-city');
            const data = nodeData[city];
            if (data) {
                // Pulse the node
                const pulseRing = node.querySelector('.node-pulse-ring');
                if (pulseRing) {
                    pulseRing.style.animation = 'none';
                    void pulseRing.offsetWidth; // Trigger reflow
                    pulseRing.style.animation = 'nodePulse 0.5s ease-out 3';
                }
            }
        });
    });

    // ===== Activity Item Click States =====
    const activityItems = document.querySelectorAll('.activity-item');
    activityItems.forEach(item => {
        item.addEventListener('click', () => {
            // Brief highlight
            item.style.borderColor = 'rgba(0, 242, 255, 0.3)';
            item.style.boxShadow = '0 0 15px rgba(0, 242, 255, 0.08)';
            setTimeout(() => {
                item.style.borderColor = '';
                item.style.boxShadow = '';
            }, 800);
        });
    });

    // ===== Balance Counter Animation =====
    const balanceValue = document.querySelector('.currency-value');
    if (balanceValue) {
        const targetValue = 84210.65;
        const duration = 1500;
        const startTime = performance.now();

        function animateBalance(currentTime) {
            const elapsed = currentTime - startTime;
            const progress = Math.min(elapsed / duration, 1);

            // Ease out cubic
            const easeOut = 1 - Math.pow(1 - progress, 3);
            const currentValue = targetValue * easeOut;

            balanceValue.textContent = currentValue.toLocaleString('en-US', {
                minimumFractionDigits: 2,
                maximumFractionDigits: 2
            });

            if (progress < 1) {
                requestAnimationFrame(animateBalance);
            }
        }

        // Delay counter animation slightly
        setTimeout(() => {
            requestAnimationFrame(animateBalance);
        }, 400);
    }

    // ===== Map Dots Carousel =====
    const mapDots = document.querySelectorAll('.map-dots .dot');
    let currentDot = 0;

    function rotateDots() {
        mapDots.forEach(d => d.classList.remove('active'));
        currentDot = (currentDot + 1) % mapDots.length;
        mapDots[currentDot].classList.add('active');
    }

    setInterval(rotateDots, 4000);

    // ===== Smooth Scroll Header Shadow =====
    const appContent = document.getElementById('appContent');
    const appHeader = document.getElementById('appHeader');

    if (appContent && appHeader) {
        appContent.addEventListener('scroll', () => {
            if (appContent.scrollTop > 10) {
                appHeader.style.boxShadow = '0 4px 20px rgba(0, 0, 0, 0.4)';
                appHeader.style.borderBottom = '1px solid rgba(255, 255, 255, 0.04)';
            } else {
                appHeader.style.boxShadow = 'none';
                appHeader.style.borderBottom = 'none';
            }
        });
    }

    // ===== Latency Badge Dynamic Update =====
    const latencyBadge = document.querySelector('.latency-badge span');
    if (latencyBadge) {
        function updateLatency() {
            const latency = Math.floor(Math.random() * 8) + 10; // 10-17ms
            latencyBadge.textContent = `${latency}ms`;
        }
        setInterval(updateLatency, 5000);
    }

    console.log('%c⚡ Crisis Bridge UI Loaded', 'color: #00f2ff; font-size: 14px; font-weight: bold;');
});
