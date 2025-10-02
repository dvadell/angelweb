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
    console.log('Chart hook mounted');
    
    // Initialize event queue for when connection is lost
    this.eventQueue = [];
    
    // Set up event listener for this specific hook instance
    this.handleDataLoaded = (e) => {
      console.log("Hook received data event:", e.detail);
      this.renderChart(e.detail.data);
    };
    
    // Listen for chart data events
    window.addEventListener("phx:chart:data_loaded", this.handleDataLoaded);
    
    this.handleNewData = (e) => {
      console.log("Hook received new data event:", e.detail);
      this.appendDataToChart(e.detail.value, e.detail.timestamp);
    };
    window.addEventListener("phx:chart:new_data", this.handleNewData);
    
    // Listen for LiveView connection events
    this.handleReconnected = () => {
      console.log('LiveView reconnected, processing queued events');
      this.processEventQueue();
    };
    
    window.addEventListener("phx:page-loading-stop", this.handleReconnected);

    // Fullscreen button handler
    const fullscreenBtn = document.getElementById('fullscreen-btn');
    const chartWrapper = document.getElementById('chart-wrapper');
    const expandIcon = document.getElementById('fullscreen-expand-icon');
    const shrinkIcon = document.getElementById('fullscreen-shrink-icon');

    if (fullscreenBtn && chartWrapper && expandIcon && shrinkIcon) {
      fullscreenBtn.addEventListener('click', () => {
        if (!document.fullscreenElement) {
          chartWrapper.requestFullscreen().catch(err => {
            alert(`Error attempting to enable full-screen mode: ${err.message} (${err.name})`);
          });
        } else {
          document.exitFullscreen();
        }
      });

      document.addEventListener('fullscreenchange', () => {
        if (document.fullscreenElement) {
          expandIcon.classList.add('hidden');
          shrinkIcon.classList.remove('hidden');
        } else {
          expandIcon.classList.remove('hidden');
          shrinkIcon.classList.add('hidden');
        }
      });
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
    if (this.handleNewData) {
      window.removeEventListener("phx:chart:new_data", this.handleNewData);
    }
  },

  appendDataToChart(value, timestamp) {
    if (this.chart) {
      // Add the new timestamp (which is already in milliseconds) to the labels
      this.chart.data.labels.push(timestamp);
      this.chart.data.datasets[0].data.push(value); // actual

      // If forecast datasets exist, push null to them to keep them aligned
      if (this.chart.data.datasets.length > 1) {
        this.chart.data.datasets[1].data.push(null);  // forecast
        this.chart.data.datasets[2].data.push(null);  // upper_bound
        this.chart.data.datasets[3].data.push(null);  // lower_bound
      }
      
      this.chart.update();
    }
  },

  // Method to render chart with new data (called from LiveView events)
  renderChart(data) {
    console.log('Hook renderChart called with data:', data);
    window.chartData = data;

    // Helper function to format milliseconds to human-readable duration
    const formatDuration = (ms) => {
      const seconds = ms / 1000;
      const minutes = seconds / 60;
      const hours = minutes / 60;
      const days = hours / 24;

      if (days >= 1) { return `${days.toFixed(1)}d`; }
      if (hours >= 1) { return `${hours.toFixed(1)}hr`; }
      if (minutes >= 1) { return `${minutes.toFixed(1)}min`; }
      if (seconds >= 1) { return `${seconds.toFixed(1)}s`; }
      return `${ms.toFixed(0)}ms`;
    };
    
    // Check if data is in the new format. If not, it might be an error fallback.
    if (!data || !data.dates) {
      console.warn('Chart data is not in the expected format, aborting render.', data);
      return;
    }

    // Destroy existing chart if any
    if (this.chart) {
      this.chart.destroy();
    }

    console.log('Creating chart on element:', this.el);
    const ctx = this.el.getContext('2d');

    // Create gradient
    const gradient = ctx.createLinearGradient(0, 0, 0, 400);
    gradient.addColorStop(0, 'rgba(34, 197, 94, 0.5)');
    gradient.addColorStop(1, 'rgba(34, 197, 94, 0)');
    
    this.chart = new Chart(ctx, {
      type: 'line',
      data: {
        labels: data.dates,
        datasets: (() => {
          const datasets = [
            {
              label: data.actual_label || 'Actual',
              data: data.actual,
              borderColor: '#22c55e',
              borderWidth: 2,
              pointRadius: 2,
              tension: 0.1,
              fill: true,
              backgroundColor: gradient,
            }
          ];

          const hasForecast = data.forecast && data.forecast.some(d => d !== null);

          if (hasForecast) {
            datasets.push({
              label: 'Forecast',
              data: data.forecast,
              borderColor: '#dc2626',
              borderWidth: 2,
              borderDash: [5, 5],
              pointRadius: 2,
              tension: 0.1,
            });
            datasets.push({
              label: 'Upper Bound',
              data: data.upper_bound,
              borderColor: 'rgba(220, 38, 38, 0.3)',
              backgroundColor: 'rgba(220, 38, 38, 0.1)',
              borderWidth: 1,
              pointRadius: 0,
              fill: '+1', // Fill to the dataset at the next index (Lower Bound)
              tension: 0.1,
            });
            datasets.push({
              label: 'Lower Bound',
              data: data.lower_bound,
              borderColor: 'rgba(220, 38, 38, 0.3)',
              backgroundColor: 'rgba(220, 38, 38, 0.1)',
              borderWidth: 1,
              pointRadius: 0,
              fill: false, // Don't fill the lower bound itself
              tension: 0.1,
            });
          }
          return datasets;
        })()
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: {
          mode: 'index',
          intersect: false,
        },
        scales: {
          x: {
            type: 'timestack',
            title: {
              display: true,
              text: 'Date'
            }
          },
          y: {
            title: {
              display: true,
              text: 'Value'
            },
            ticks: {
              callback: (value) => {
                if (data.graph_type === 'time') {
                  return formatDuration(value);
                }
                return value;
              }
            }
          }
        },
        plugins: {
          zoom: {
            zoom: {
              wheel: { enabled: true },
              pinch: { enabled: true },
              mode: 'x',
              onZoomComplete: (context) => this.handleZoom(context)
            },
            pan: { 
              enabled: true,
              mode: 'x',
              onPanComplete: (context) => this.handlePan(context)
            }
          },
          annotation: {
            annotations: {
              ...(typeof data.min_value === 'number' && {
                minLine: {
                  type: 'line',
                  yMin: data.min_value,
                  yMax: data.min_value,
                  borderColor: 'rgb(255, 150, 150)',
                  borderDash: [10, 10],
                  borderWidth: 2,
                  label: {
                    content: `Min: ${data.graph_type === 'time' ? formatDuration(data.min_value) : data.min_value}`,
                    display: true,
                    backgroundColor: 'rgba(255, 150, 150, 0.3)',
                    color: '000',
                  }
                }
              }),
              ...(typeof data.max_value === 'number' && {
                maxLine: {
                  type: 'line',
                  yMin: data.max_value,
                  yMax: data.max_value,
                  borderColor: 'rgb(255, 150, 150)',
                  borderDash: [10, 10],
                  borderWidth: 2,
                  label: {
                    content: `Max: ${data.graph_type === 'time' ? formatDuration(data.max_value) : data.max_value}`,
                    display: true,
                    backgroundColor: 'rgba(255, 150, 150, 0.3)',
                    color: '000',
                  }
                }
              })
            }
          },
          tooltip: {
            callbacks: {
              label: function(context) {
                let label = context.dataset.label || '';
                if (label) { label += ': '; }
                if (context.parsed.y !== null) {
                  if (data.graph_type === 'time') {
                    label += formatDuration(context.parsed.y);
                  } else {
                    label += context.parsed.y.toFixed(2);
                  }
                }
                return label;
              }
            }
          }
        }
      }
    });
    
    window.chart = this.chart;
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

let LocalTimeHook = {
  mounted() { this.formatTime() },
  updated() { this.formatTime() },
  formatTime() {
    this.el.querySelectorAll('[data-timestamp]').forEach(el => {
      const utcTime = el.dataset.timestamp
      if (!utcTime) { return }
      const date = new Date(utcTime)
      const options = {
        year: 'numeric',
        month: 'short',
        day: 'numeric',
        hour: 'numeric',
        minute: '2-digit'
      }
      el.textContent = date.toLocaleString(undefined, options)
    })
  }
}

let Hooks = {
  Chart: ChartHook,
  LocalTime: LocalTimeHook
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
