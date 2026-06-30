const MentionHook = {
  mounted() {
    // Find all text inputs in the post component
    const textInputs = this.el.querySelectorAll('input[type="text"], textarea');
    
    textInputs.forEach(input => {
      input.addEventListener('input', (e) => this.handleInput.call(this, e));
      input.addEventListener('keydown', (e) => this.handleKeyDown.call(this, e));
    });
  },

  destroyed() {
    const textInputs = this.el.querySelectorAll('input[type="text"], textarea');
    textInputs.forEach(input => {
      input.removeEventListener('input', this.handleInput.bind(this));
      input.removeEventListener('keydown', this.handleKeyDown.bind(this));
    });
  },

  handleInput(e) {
    const value = e.target.value;
    const cursorPos = e.target.selectionStart;
    
    // Check if @ was just typed
    const beforeCursor = value.substring(0, cursorPos);
    const atMatch = beforeCursor.match(/@(\w*)$/);
    
    if (atMatch) {
      const searchTerm = atMatch[1];
      if (searchTerm.length >= 2) {
        this.searchUsers(searchTerm);
        this.showModal();
      }
    } else {
      this.hideModal();
    }
  },

  handleKeyDown(e) {
    if (e.key === 'Escape') {
      this.hideModal();
    }
  },

  searchUsers(query) {
    this.pushEvent("search_mentions", { query: query });
  },

  showModal() {
    const modal = document.getElementById('mention-modal');
    if (modal) {
      modal.classList.remove('hidden');
    }
  },

  hideModal() {
    const modal = document.getElementById('mention-modal');
    if (modal) {
      modal.classList.add('hidden');
    }
  }
};

export default MentionHook;
