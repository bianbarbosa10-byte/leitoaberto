// Aplica o tema salvo antes de desenhar a pagina (evita piscar). Arquivo externo para permitir CSP sem 'unsafe-inline'.
try { var t = localStorage.getItem("tema"); if (t === "light" || t === "dark") document.documentElement.dataset.theme = t; } catch (e) {}
