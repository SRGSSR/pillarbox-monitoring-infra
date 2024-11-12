# Grafana Dashboard Export Guide

This guide provides step-by-step instructions to export dashboards from Grafana. You can export
either a single dashboard directly through the Grafana interface or all dashboards within a
specified folder using a custom script.

## Exporting a Single Dashboard

To export an individual dashboard directly through the Grafana interface, follow these steps:

1. Open the dashboard you wish to export.
2. Click the Share button (usually located at the top right).
3. In the Share panel, navigate to the Export tab.
4. Select Save to file. This will download a JSON file of the dashboard's configuration to your
   computer.

## Exporting All Dashboards in a Folder

The following steps outline a method to export all dashboards within a specified folder in Grafana
as a single zip file containing individual JSON files for each dashboard.

### 1. Open the Browser Console

- Open your Grafana instance and log in if prompted by SSO.
- Press <kbd>F12</kbd> (or right-click and select **Inspect**) to open Developer Tools.
- Navigate to the **Console** tab.

### 2. Load JSZip Library

- To manage multiple files in a zip, we’ll use the [JSZip library](https://stuk.github.io/jszip/).
  Copy and paste the following code into the console and press <kbd>Enter</kbd>:

  ```javascript
  var script = document.createElement('script');
  script.src = 'https://cdnjs.cloudflare.com/ajax/libs/jszip/3.10.1/jszip.min.js';
  document.head.appendChild(script);
  ```

- Verify that JSZip is loaded by typing `JSZip` into the console and pressing <kbd>Enter</kbd>. You
  should
  see an object or function returned.

### 3. Run the Export Script

- Copy and paste the following code into the console and press <kbd>Enter</kbd>:

  ```javascript
  async function exportAllDashboardsWithFolders() {
      const zip = new JSZip();

      // Step 1: Get all folders
      const folderResponse = await fetch(`/api/folders`);
      const folders = await folderResponse.json();
      const folderMap = {};
      folders.forEach(folder => {
          folderMap[folder.uid] = folder.title.replace(/[/\\?%*:|"<>]/g, ''); // Clean up folder names
      });

      // Step 2: Fetch all dashboards across folders
      const response = await fetch(`/api/search?type=dash-db`);
      const dashboards = await response.json();

      for (const dashboard of dashboards) {
          const uid = dashboard.uid;
          const title = dashboard.title.replace(/[/\\?%*:|"<>]/g, ''); // Clean up filename
          const folderName = folderMap[dashboard.folderUid] || 'General';

          // Fetch each dashboard's JSON
          const dashboardResponse = await fetch(`/api/dashboards/uid/${uid}`);
          const dashboardData = await dashboardResponse.json();

          // Add each dashboard JSON to the zip, organized by folder
          zip.file(`${folderName}/${title}.json`, JSON.stringify(dashboardData.dashboard, null, 2));
          console.log(`Added to zip: ${folderName}/${title}`);
      }

      // Step 3: Generate the zip and trigger download
      zip.generateAsync({ type: 'blob' }).then(function (content) {
          const link = document.createElement('a');
          link.href = URL.createObjectURL(content);
          link.download = 'grafana_dashboards.zip';
          document.body.appendChild(link);
          link.click();
          document.body.removeChild(link);
          console.log("Downloaded all dashboards as zip with folder structure.");
      });
  }

  exportAllDashboardsWithFolders();
  ```
- The script will create a zip containing individual JSON files for each dashboard and will follow
  Grafana folder structure.
- Each JSON file is named after the dashboard title and represents a backup of the dashboard’s
  configuration.
