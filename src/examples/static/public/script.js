console.log('Dream static file serving works!');
console.log('Current path:', window.location.pathname);
console.log('Served at:', new Date().toISOString());

// Add a simple interaction
document.addEventListener('DOMContentLoaded', function() {
  console.log('Page fully loaded');
  
  // Highlight current page in navigation
  const links = document.querySelectorAll('a');
  links.forEach(link => {
    if (link.getAttribute('href') === window.location.pathname) {
      link.style.fontWeight = 'bold';
      link.style.color = '#e74c3c';
    }
  });
});

