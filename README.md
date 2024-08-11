# AV1 | Tdarr Setup and/or Node Killer (Optional) | Unraid Plugin - Guide

## Purpose

This guide is designed to help users optimize their media libraries using AV1 encoding while efficiently managing GPU resources between Plex and Tdarr. By following this guide, you will learn how to reduce video file sizes, freeing up significant storage space, and how to automate GPU resource allocation to ensure Plex users experience smooth playback without interference from Tdarr processes.

---

## Table of Contents

- [Upgrading to Unraid 7.0 and Installing Required Plugins](#upgrading-to-unraid-70-and-installing-required-plugins)
  - [Installing Intel GPU TOP Plugin](#installing-intel-gpu-top-plugin)
  - [Installing GPU Statistics Plugin](#installing-gpu-statistics-plugin)
- [AV1 Tdarr Flow](#av1-tdarr-flow)
- [Tdarr Node Killer Script](#tdarr-node-killer-script)
- [Experimental: Running the Script on Other Operating Systems](#experimental-running-the-script-on-other-operating-systems)

---

## Upgrading to Unraid 7.0 and Installing Required Plugins

Before setting up the AV1 Tdarr Flow or the Tdarr Node Killer Script, ensure that you are running Unraid 7.0 and have the necessary plugins installed to monitor and manage your Intel ARC GPU.

### Installing Intel GPU TOP Plugin

The first plugin to install is the **Intel GPU TOP** by ich777. This plugin is essential for monitoring your Intel ARC GPU’s performance.

- **Plugin Developer**: ich777
- **Installation**: Available through the Unraid Community Applications
- **GitHub Repository**: [Intel GPU TOP by ich777](https://github.com/ich777)

![Intel GPU TOP Plugin](https://i.imgur.com/0bHRqya.png)

### Installing GPU Statistics Plugin

Next, install the **GPU Statistics** plugin by b3rs3rk. This plugin provides detailed statistics on GPU usage, helping you verify that your Intel ARC GPU is working correctly.

- **Plugin Developer**: b3rs3rk
- **Installation**: Available through the Unraid Community Applications

![GPU Statistics Plugin](https://i.imgur.com/lJZgPvC.png)

With these plugins installed, you can monitor your Intel ARC GPU during transcoding and other tasks. Below are examples of what you can expect to see when your Intel ARC GPU is in use:

![GPU in Use Example 1](https://i.imgur.com/toOvgvN.png)

![GPU in Use Example 2](https://i.imgur.com/jDbrB5a.png)

---

## AV1 Tdarr Flow

![AV1 Flow](https://i.imgur.com/FiFVxgT.png)

### What is the AV1 Flow?

The AV1 encoding flow is a process that converts video data into the AV1 format, known for its high efficiency and excellent compression. The flow involves:

1. **Source**: Your original video file.
2. **Input Processing**: Preparing the video by adjusting resolution, color space, and more.
3. **Encoding**: The AV1 encoder compresses the video data, making the file smaller without losing too much quality.
4. **Output**: The final, compressed AV1 video file is ready for streaming or storage.

**Note:** This flow should work on any operating system that has an Intel ARC GPU card. You just need to ensure that the ARC GPU is exposed in your Tdarr Docker container.

### Setting Up the Tdarr Node Docker Container in Unraid

To ensure your Tdarr node is properly configured in Unraid, follow these steps:

1. **Ensure Consistency in Naming**: The template name and the node name should be the same. This is important because if you use the Tdarr Node Killer Script, you want this to also be the exact same name. This makes it easier to manage and avoid conflicts.

    ![Example of Consistent Naming](https://imgur.com/h4ja0DH.png)

2. **Use the Correct Repository**: For the Tdarr node, use the following repository: `ghcr.io/haveagitgat/tdarr_node`. While you can enable the server node within the same container, it's generally a bad idea. If the Node Killer Script stops the server, it can take a long time to reload and rescan everything. It's better to disable the internal server node and deploy a separate node.

3. **Add the Intel ARC GPU Card to the Template**: You need to add the Intel ARC GPU card to the Tdarr node Docker container template for it to use the GPU effectively.

    ![Add Intel ARC GPU to Template](https://i.imgur.com/QOIUCIc.png)

    To do this, open up the Unraid command line and navigate to `/dev/dri` by typing:

    ```bash
    cd /dev/dri
    ls
    ```

    You should see different render devices listed. Select the correct one for your GPU and input it in the Docker container setup as shown in the picture above.

By following these steps, you’ll deploy a proper Tdarr node container, ensuring it has access to the correct GPU.

---

## Tdarr Node Killer Script

### Overview

The Tdarr Node Killer Script is designed to manage your GPU resources between Plex and Tdarr efficiently. It ensures that when Plex starts transcoding, the Tdarr node using the same GPU is automatically stopped, preventing any conflicts.

### Script Behavior

1. **Monitoring Plex**: The script continuously monitors Plex for any transcoding activity. When Plex starts transcoding, the script kills the Tdarr node using the same GPU.
2. **Five-Minute Check Cycle**: After stopping the Tdarr node, the script checks every 5 seconds for 5 minutes to see if Plex has finished transcoding.
   - If no transcoding is detected during this time, the Tdarr node is restarted.
   - If transcoding is detected at any point, the timer resets, and the script continues monitoring.

This setup allows you to put the GPU back to work when Plex is idle, while ensuring Plex users always get priority when transcoding is required.

### Step-by-Step Implementation

1. **Save the Script**: Save your Tdarr Node Killer Script as `tdarr_node_killer.sh` in `/usr/local/bin/`.

    ```bash
    sudo nano /usr/local/bin/tdarr_node_killer.sh
    ```

2. **Set the Proper Permissions**:

    Ensure that the script has the correct permissions to execute. Use the following commands:

    ```bash
    sudo chmod +x /usr/local/bin/tdarr_node_killer.sh
    sudo chown root:root /usr/local/bin/tdarr_node_killer.sh
    ```

3. **Create a Service File (For Non-Unraid Users)**: If you're not using Unraid, you can run this script as a service on your operating system. Create a service file for the script:

    ```bash
    sudo nano /etc/systemd/system/tdarr_node_killer.service
    ```

4. **Add the Following Content**:

    ```ini
    [Unit]
    Description=Tdarr Node Killer Script
    After=network.target

    [Service]
    Type=simple
    ExecStart=/bin/bash /usr/local/bin/tdarr_node_killer.sh
    Restart=on-failure

    [Install]
    WantedBy=multi-user.target
    ```

5. **Reload Systemd**:

    ```bash
    sudo systemctl daemon-reload
    ```

6. **Start and Enable the Service**:

    ```bash
    sudo systemctl start tdarr_node_killer.service
    sudo systemctl enable tdarr_node_killer.service
    ```

By following these steps, the script will run automatically on startup and ensure that it stays active in the background, managing your GPU resources efficiently.

---

## Experimental: Running the Script on Other Operating Systems

While this script is designed to work seamlessly on Unraid, it can technically work on any operating system that supports Docker and systemd services. The steps provided in the Tdarr Node Killer Script section above can be adapted for use on systems like Ubuntu, CentOS, or any other Linux distribution that uses systemd.

If you’re using a different operating system and want to try this setup, follow the steps provided for saving the script, setting permissions, and creating a service file. The service will automatically start on boot and manage the Tdarr node and Plex transcoding as described.

---

## Summary

The Tdarr Node Killer Script is designed to intelligently manage GPU resources between Plex and Tdarr. By monitoring Plex transcoding activity and controlling the Tdarr node, the script ensures that your Intel ARC GPU is used efficiently. This guide provides a visual walkthrough of the process, making it easy for beginners to understand how the script works and how to configure it for their own use.
