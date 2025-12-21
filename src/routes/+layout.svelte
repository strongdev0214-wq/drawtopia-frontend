<!-- Root layout for all pages -->
<script lang="ts">
  import { onMount } from 'svelte';
  import { browser } from '$app/environment';
  import { initAuth } from '$lib/stores/auth';
  import { registerServiceWorker } from '$lib/pushNotifications';
  import NotificationContainer from '../components/NotificationContainer.svelte';
  import '../app.css';

  // Initialize authentication and push notifications on app startup
  onMount(async () => {
    const unsubscribe = initAuth();
    
    // Register service worker for push notifications
    if (browser) {
      try {
        await registerServiceWorker();
        console.log('Service worker registered successfully');
      } catch (error) {
        console.error('Failed to register service worker:', error);
      }
    }
    
    // Cleanup on component destroy
    return unsubscribe;
  });
</script>

<main>
  <slot />
</main>

<!-- Global notification container -->
<NotificationContainer />

<style>
  :global(body) {
    margin: 0;
    padding: 0;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen',
      'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue',
      sans-serif;
    -webkit-font-smoothing: antialiased;
    -moz-osx-font-smoothing: grayscale;
  }

  :global(*) {
    box-sizing: border-box;
  }

  main {
    width: 100%;
    min-height: 100vh;
  }
</style>