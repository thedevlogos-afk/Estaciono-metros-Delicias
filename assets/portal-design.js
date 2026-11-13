document.querySelectorAll('[data-field-go]').forEach(button=>button.addEventListener('click',()=>document.querySelector('[data-tab="'+button.dataset.fieldGo+'"]').click()));
