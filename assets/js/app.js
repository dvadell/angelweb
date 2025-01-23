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
//import 'chartjs-adapter-date-fns';
import 'chartjs-scale-timestack';

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken}
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

// See also https://medium.com/@lionel.aimerie/integrating-chart-js-into-elixir-phoenix-for-visual-impact-9a3991f0690f
Chart.register(zoomPlugin);

//window.addEventListener("DOMContentLoaded", () => {
//  fetchGraphData("stats.gauges.jr.load_avg");
//});

//function fetchGraphData(graph_name) {
//  fetch('http://localhost:80/render?target=' + graph_name + '&from=-24hours&format=json')
//    .then(response => response.json())
//    .then(data => renderChart(data));
//}

// data looks like this:
// data[0].datapoints is an array of 1440 arrays [value, timestamp]
function renderChart(data) {
  window.data = data;
  console.log(data);
  const ctx = document.getElementById('myChart').getContext('2d');
  new Chart(ctx, {
    type: 'line',
    data: {
      labels: data[0].datapoints.map( item => item[1] * 1000), // need miliseconds
      datasets: [{
        label: data[0].tags.name,
        data: data[0].datapoints.map( item => item[0])
      }]
    },
    options: {
      scales: {
        x: { type: 'timestack' },
      },
      plugins: {
        zoom: {
          zoom: {
            wheel: { enabled: true },
            pinch: { enabled: true },
            mode: 'x'
          },
          pan: { enabled: true }
        }
      }
    },
  });
}

console.log("Exporting renderChart");
window.renderChart = renderChart;

