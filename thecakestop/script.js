/* =============================================
   THE CAKE STOP — JavaScript
   Navigation, Tabs, Scroll Animations, Interactions
   ============================================= */

document.addEventListener('DOMContentLoaded', () => {

    // --- Navbar Scroll Effect ---
    const navbar = document.getElementById('navbar');
    const backToTop = document.getElementById('backToTop');

    window.addEventListener('scroll', () => {
        const scrollY = window.scrollY;

        // Navbar background on scroll
        if (scrollY > 60) {
            navbar.classList.add('scrolled');
        } else {
            navbar.classList.remove('scrolled');
        }

        // Back to top button
        if (scrollY > 400) {
            backToTop.classList.add('visible');
        } else {
            backToTop.classList.remove('visible');
        }
    });

    // Back to top click
    backToTop.addEventListener('click', () => {
        window.scrollTo({ top: 0, behavior: 'smooth' });
    });

    // --- Mobile Menu Toggle ---
    const mobileToggle = document.getElementById('mobileToggle');
    const navLinks = document.getElementById('navLinks');

    mobileToggle.addEventListener('click', () => {
        navLinks.classList.toggle('open');
        mobileToggle.classList.toggle('active');
    });

    // Close mobile menu on link click
    navLinks.querySelectorAll('a').forEach(link => {
        link.addEventListener('click', () => {
            navLinks.classList.remove('open');
            mobileToggle.classList.remove('active');
        });
    });

    // --- Menu Tabs ---
    const tabBtns = document.querySelectorAll('.tab-btn');
    const menuItems = document.querySelectorAll('.menu-items');

    tabBtns.forEach(btn => {
        btn.addEventListener('click', () => {
            const target = btn.dataset.tab;

            // Remove active from all
            tabBtns.forEach(b => b.classList.remove('active'));
            menuItems.forEach(m => m.classList.remove('active'));

            // Activate clicked
            btn.classList.add('active');
            document.querySelector(`[data-tab-content="${target}"]`).classList.add('active');
        });
    });

    // --- Smooth Scroll for Anchor Links ---
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', (e) => {
            const targetId = anchor.getAttribute('href');
            if (targetId === '#') return;

            const targetEl = document.querySelector(targetId);
            if (targetEl) {
                e.preventDefault();
                const navHeight = navbar.offsetHeight;
                const targetPosition = targetEl.getBoundingClientRect().top + window.scrollY - navHeight - 20;

                window.scrollTo({
                    top: targetPosition,
                    behavior: 'smooth'
                });
            }
        });
    });

    // --- Scroll Reveal Animation ---
    const revealElements = document.querySelectorAll(
        '.about-card, .menu-item, .review-card, .contact-card, .gallery-item, .review-score, .section-header, .menu-cta, .cta-content'
    );

    revealElements.forEach(el => el.classList.add('reveal'));

    const revealObserver = new IntersectionObserver((entries) => {
        entries.forEach((entry, index) => {
            if (entry.isIntersecting) {
                // Stagger the animation
                setTimeout(() => {
                    entry.target.classList.add('visible');
                }, index * 80);
                revealObserver.unobserve(entry.target);
            }
        });
    }, {
        threshold: 0.1,
        rootMargin: '0px 0px -40px 0px'
    });

    revealElements.forEach(el => revealObserver.observe(el));

    // --- Active Nav Link Highlighting ---
    const sections = document.querySelectorAll('section[id]');

    const highlightNav = () => {
        const scrollPos = window.scrollY + 100;

        sections.forEach(section => {
            const top = section.offsetTop;
            const height = section.offsetHeight;
            const id = section.getAttribute('id');
            const navLink = document.querySelector(`.nav-links a[href="#${id}"]`);

            if (navLink) {
                if (scrollPos >= top && scrollPos < top + height) {
                    navLink.style.color = 'var(--color-text)';
                    navLink.style.setProperty('--underline-width', '100%');
                } else {
                    navLink.style.color = '';
                    navLink.style.setProperty('--underline-width', '0');
                }
            }
        });
    };

    window.addEventListener('scroll', highlightNav);

    // --- Parallax on Hero Shapes ---
    const shapes = document.querySelectorAll('.shape');

    window.addEventListener('scroll', () => {
        const scrollY = window.scrollY;
        shapes.forEach((shape, i) => {
            const speed = 0.05 + (i * 0.02);
            shape.style.transform = `translateY(${scrollY * speed}px)`;
        });
    });

    // --- Hover ripple on cards ---
    document.querySelectorAll('.about-card, .menu-item, .review-card, .contact-card').forEach(card => {
        card.addEventListener('mousemove', (e) => {
            const rect = card.getBoundingClientRect();
            const x = e.clientX - rect.left;
            const y = e.clientY - rect.top;
            card.style.setProperty('--mouse-x', `${x}px`);
            card.style.setProperty('--mouse-y', `${y}px`);
        });
    });

    // --- Console Easter Egg ---
    console.log('%c🎂 The Cake Stop', 'font-size: 24px; font-weight: bold; color: #E74C3C;');
    console.log('%cVile Parle East, Mumbai | +91 92235 47022', 'font-size: 12px; color: #F39C12;');
});
