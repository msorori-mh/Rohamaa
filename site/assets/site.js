'use strict';
// Navigation is usable without JavaScript. No tracking or form data collection.
const toggle = document.querySelector('.menu-toggle');
const nav = document.querySelector('#main-nav');
if (toggle && nav) {
  document.documentElement.classList.add('js');
  toggle.hidden = false;
  const close = (restoreFocus = false) => {
    nav.classList.remove('is-open');
    toggle.setAttribute('aria-expanded', 'false');
    if (restoreFocus) toggle.focus();
  };
  toggle.addEventListener('click', () => {
    const opened = toggle.getAttribute('aria-expanded') !== 'true';
    toggle.setAttribute('aria-expanded', String(opened));
    nav.classList.toggle('is-open', opened);
  });
  nav.addEventListener('click', event => {
    if (event.target.closest('a')) close();
  });
  document.addEventListener('keydown', event => {
    if (event.key === 'Escape' && toggle.getAttribute('aria-expanded') === 'true') close(true);
  });
  document.addEventListener('click', event => {
    if (!event.target.closest('.site-header')) close();
  });
  window.matchMedia('(min-width: 761px)').addEventListener('change', () => close());
}
