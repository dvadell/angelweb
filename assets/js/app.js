// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"
import Chart from 'chart.js/auto';
import zoomPlugin from 'chartjs-plugin-zoom';
import 'chartjs-scale-timestack';
import annotationPlugin from 'chartjs-plugin-annotation';

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

// Chart.js Hook for LiveView
let ChartHook = {
  mounted() {
    Chart.register(zoomPlugin, annotationPlugin);
    console.log('Chart hook mounted - requesting initial data');
    
    // Initialize event queue for when connection is lost
    this.eventQueue = [];
    
    // Set up event listener for this specific hook instance
    this.handleDataLoaded = (e) => {
      console.log("Hook received data event:", e.detail);
      this.renderChart(e.detail.data);
    };
    
    // Listen for chart data events
    window.addEventListener("phx:chart:data_loaded", this.handleDataLoaded);
    
    // Listen for LiveView connection events
    this.handleReconnected = () => {
      console.log('LiveView reconnected, processing queued events');
      this.processEventQueue();
    };
    
    window.addEventListener("phx:page-loading-stop", this.handleReconnected);
    
    // Request initial data from LiveView (with retry if not connected)
    this.requestInitialData();
  },

  requestInitialData() {
    if (window.liveSocket.isConnected()) {
      this.pushEvent("get_initial_data", {});
    } else {
      console.log('LiveView not connected yet, retrying in 100ms...');
      setTimeout(() => this.requestInitialData(), 100);
    }
  },

  queueEvent(eventName, payload) {
    this.eventQueue.push({ eventName, payload, timestamp: Date.now() });
    
    // Keep only recent events (last 30 seconds)
    const cutoff = Date.now() - 30000;
    this.eventQueue = this.eventQueue.filter(event => event.timestamp > cutoff);
    
    console.log(`Queued ${eventName} event (${this.eventQueue.length} total)`);
  },

  processEventQueue() {
    if (this.eventQueue.length === 0) return;
    
    console.log(`Processing ${this.eventQueue.length} queued events`);
    
    // Process only the most recent event of each type to avoid spam
    const latestEvents = {};
    this.eventQueue.forEach(event => {
      latestEvents[event.eventName] = event;
    });
    
    Object.values(latestEvents).forEach(event => {
      try {
        this.pushEvent(event.eventName, event.payload);
      } catch (error) {
        console.warn('Failed to process queued event:', error);
      }
    });
    
    this.eventQueue = [];
  },

  updated() {
    // Re-initialize chart when LiveView updates
    console.log('Chart hook updated');
    // Don't automatically re-request data on update
    // Let LiveView decide when to send new data
  },

  destroyed() {
    // Clean up chart and event listener when element is removed
    console.log('Chart hook destroyed');
    if (this.chart) {
      this.chart.destroy();
    }
    
    // Remove event listeners
    if (this.handleDataLoaded) {
      window.removeEventListener("phx:chart:data_loaded", this.handleDataLoaded);
    }
    if (this.handleReconnected) {
      window.removeEventListener("phx:page-loading-stop", this.handleReconnected);
    }
  },

  // Method to render chart with new data (called from LiveView events)
  renderChart(data) {
    console.log('Hook renderChart called with data:', data);
    
    if (!data || !data[0] || !data[0].datapoints) {
      console.warn('Invalid chart data structure:', data);
      return;
    }

    // Destroy existing chart if any
    if (this.chart) {
      this.chart.destroy();
    }

    console.log('Creating chart on element:', this.el);
    const ctx = this.el.getContext('2d');
    
    this.chart = new Chart(ctx, {
      type: 'line',
      data: {
        labels: data[0].datapoints.map(item => item[1]),
        datasets: [{
          label: data[0].target || 'Data',
          data: data[0].datapoints.map(item => item[0])
        }]
      },
      options: {
        animation: false,
        scales: {
          x: { type: 'timestack' },
        },
        plugins: {
          zoom: {
            zoom: {
              wheel: { enabled: true },
              pinch: { enabled: true },
              mode: 'x',
              onZoom: (context) => {
                this.handleZoom(context);
              }
            },
            pan: { 
              enabled: true,
              mode: 'x',
              onPan: (context) => {
                this.handlePan(context);
              }
            }
          },
          annotation: {
            // See https://www.chartjs.org/chartjs-plugin-annotation/latest/guide/types/line.html
            annotations: {
              ...(typeof data[0].min_value === 'number' && {
                minLine: {
                  type: 'line',
                  yMin: data[0].min_value,
                  yMax: data[0].min_value,
                  borderColor: 'rgb(255, 150, 150)',
                  borderDash: [10, 10],
                  borderWidth: 2,
                  label: {
                    content: `Min: ${data[0].min_value}`,
                    enabled: true,
                    position: 'end'
                  }
                }
              }),
              ...(typeof data[0].max_value === 'number' && {
                maxLine: {
                  type: 'line',
                  yMin: data[0].max_value,
                  yMax: data[0].max_value,
                  borderColor: 'rgb(255, 150, 150)',
                  borderDash: [10, 10],
                  borderWidth: 2,
                  label: {
                    content: `Max: ${data[0].max_value}`,
                    display: true,
                    backgroundColor: 'rgba(255, 150, 150, 0.3)',
                    color: '000',
                    //position: 'end'
                  }
                }
              })
            }
          }
        }
      },
    });
    
    console.log('Chart created successfully:', this.chart);
  },

  handleZoom({chart}) {
    const xScale = chart.scales.x;
    const visibleRange = {
      min: xScale.min,
      max: xScale.max
    };
    
    console.log('Chart zoomed:', visibleRange);
    
    const zoomLevel = (xScale.max - xScale.min) / (xScale.options.max - xScale.options.min);
    const payload = {
      visible_range: visibleRange,
      zoom_level: zoomLevel
    };
    
    // Check if LiveView is connected before pushing events
    if (window.liveSocket.isConnected()) {
      try {
        this.pushEvent("chart_zoomed", payload);
      } catch (error) {
        console.warn('Failed to send zoom event:', error);
        this.queueEvent("chart_zoomed", payload);
      }
    } else {
      console.log('LiveView not connected, queueing zoom event');
      this.queueEvent("chart_zoomed", payload);
    }
  },

  handlePan({chart}) {
    const xScale = chart.scales.x;
    const visibleRange = {
      min: xScale.min,
      max: xScale.max
    };
    
    console.log('Chart panned:', visibleRange);
    
    const payload = {
      visible_range: visibleRange
    };
    
    // Check if LiveView is connected before pushing events
    if (window.liveSocket.isConnected()) {
      try {
        this.pushEvent("chart_panned", payload);
      } catch (error) {
        console.warn('Failed to send pan event:', error);
        this.queueEvent("chart_panned", payload);
      }
    } else {
      console.log('LiveView not connected, queueing pan event');
      this.queueEvent("chart_panned", payload);
    }
  }
}

let Hooks = {
  Chart: ChartHook
}

let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: Hooks
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

console.log("Chart.js LiveView Hook loaded");
