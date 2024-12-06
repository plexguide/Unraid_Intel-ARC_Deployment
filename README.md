##### WANT TO HELP? CLICK THE ★ (STAR LOGO) in the Upper-Right! 

# Guide to Intel ARC AV1 Endocing via Unraid + Tdarr Node Killer + SAB Speed Control (Bonus)

## Intel ARC Script & Purpose

This comprehensive guide provides a step-by-step approach to optimizing your media library through AV1 encoding while efficiently managing GPU resources between Plex and Tdarr on Unraid. By following this guide, you'll learn how to drastically reduce video file sizes, saving valuable storage space, and automate the allocation of GPU resources to ensure smooth and uninterrupted playback for Plex users.

In addition to encoding and resource management, this guide covers essential information on setting up and configuring necessary plugins, importing and applying AV1 encoding flows, troubleshooting common issues, and implementing backup and recovery strategies. Whether you're a seasoned Unraid user or new to media server management, this guide equips you with the knowledge and tools needed to maximize your server's performance and efficiency.

## NOTE

This requires Unraid 7.0 (which is in beta at this time). I have an AMD 7900 - 3 Intel ARC Cards - 64GB DDR5 RAM - Two 4TB NVME Drives - 350+ TB of drives running many Docker containers and have zero problems. I run no VMs nor any passthrough (which always complicates things). Remember, it's always at your own risk. 

**Apple TV Users: ** Force Apple TV to Play AV1 Natively! No Transcoding from the GPU @ https://github.com/plexguide/AV1-AppleTV

---

## Table of Contents

- [Data Savings with AV1 Encoding](#data-savings-with-av1-encoding)
- [AV1 Drawbacks](#av1-drawbacks)
- [Upgrading to Unraid 7.0 and Installing Required Plugins](#upgrading-to-unraid-70-and-installing-required-plugins)
  - [Installing Intel GPU TOP Plugin](#installing-intel-gpu-top-plugin)
  - [Installing GPU Statistics Plugin](#installing-gpu-statistics-plugin)
- [Deploying Plex with Intel ARC GPU Support](#deploying-plex-with-intel-arc-gpu-support)
  - [Adding the Intel ARC GPU to the Plex Docker Template](#adding-the-intel-arc-gpu-to-the-plex-docker-template)
  - [Configuring Plex Settings](#configuring-plex-settings)
  - [Verifying GPU Transcoding](#verifying-gpu-transcoding)
- [AV1 Tdarr Flow](#av1-tdarr-flow)
  - [What is the AV1 Flow?](#what-is-the-av1-flow)
  - [Importing the AV1 Flow in Tdarr](#importing-the-av1-flow-in-tdarr)
- [Optimizing AV1 Encoding Settings](#optimizing-av1-encoding-settings)
- [Tdarr Node Killer Script](#tdarr-node-killer-script)
  - [Overview](#overview)
  - [Script Behavior](#script-behavior)
  - [Step-by-Step Implementation for Unraid](#step-by-step-implementation-for-unraid)
  - [Script Behavior After Plex Transcoding Stops](#script-behavior-after-plex-transcoding-stops)
  - [Troubleshooting Common Issues](#troubleshooting-common-issues)
- [Experimental: Running the Script on Other Operating Systems](#experimental-running-the-script-on-other-operating-systems)
  - [Step-by-Step Implementation for Other OSes](#step-by-step-implementation-for-other-oses)
- [Backup and Recovery Tips](#backup-and-recovery-tips)
- [Summary](#summary)

---

## Data Savings with AV1 Encoding

Running this setup with three ARC GPUs has shown significant data savings over two weeks. With AV1 encoding, a savings of 37TB was achieved, covering only 10-15% of the library.

<img width="438" alt="image" src="https://github.com/user-attachments/assets/1543f745-828f-47ba-86b2-9ddd5b9d189c">


**Explanation**: AV1 encoding can drastically reduce storage needs. For example, a 300TB library could be reduced to 75-100TB, making it an efficient solution for large media libraries. In this picture above, the 3 Intel ARC cards have been transconding for about 3 weeks and still going!

---

## AV1 Drawbacks

For more information on the potential drawbacks of using AV1 encoding, including device compatibility issues and increased resource usage during transcoding, please visit the [AV1 Drawbacks page](https://github.com/plexguide/Unraid_Intel-ARC_Deployment/wiki/AV1-Drawbacks).

---

## Upgrading to Unraid 7.0 and Installing Required Plugins
 
Before setting up the AV1 Tdarr Flow or the Tdarr Node Killer Script (totally optional and not needed), ensure that you are running Unraid 7.0 and have the necessary plugins installed to monitor and manage your Intel ARC GPU.

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

## Deploying Plex with Intel ARC GPU Support

### Adding the Intel ARC GPU to the Plex Docker Template

In Unraid, you need to add the Intel ARC GPU to your Plex Docker template as a device. Ensure that this is done correctly by adding the device at the end of your template configuration:

![Add Intel ARC GPU to Plex Template](https://i.imgur.com/Da4oeGV.png)

### Configuring Plex Settings

After adding the GPU to the Docker template, you need to configure Plex to ensure it uses the Intel ARC GPU for transcoding. 

1. **Turn On HDR Tone Mapping**: Tone Mapping now works!

<img width="1020" alt="image" src="https://github.com/user-attachments/assets/2ed05f55-ee92-4011-9f6f-99c24b5d1a3f">

### Verifying GPU Transcoding

If everything is configured correctly, Plex should use the Intel ARC GPU for transcoding. You can verify that your GPU is being used by checking the Plex dashboard during transcoding:

![Plex Transcoding with Intel ARC GPU](https://i.imgur.com/Zz9jfYo.png)

**Insight**: Properly configuring Plex to use your Intel ARC GPU can significantly improve transcoding performance while reducing CPU load. This is especially beneficial when handling multiple streams or when you want to optimize power consumption and system efficiency.

---

## AV1 Tdarr Flow

<img width="824" alt="image" src="https://github.com/user-attachments/assets/54e5b72c-5f88-4264-a01c-833a8d67287c">

### What is the AV1 Flow?

The AV1 encoding flow is a process that converts video data into the AV1 format, known for its high efficiency and excellent compression. The flow involves:

1. **Source**: Your original video file.
2. **Input Processing**: Preparing the video by adjusting resolution, color space, and more.
3. **Encoding**: The AV1 encoder compresses the video data, making the file smaller without losing too much quality.
4. **Output**: The final, compressed AV1 video file is ready for streaming or storage.

**Note:** This flow should work on any operating system that has an Intel ARC GPU card. You just need to ensure that the ARC GPU is exposed in your Tdarr Docker container.

### Importing the AV1 Flow in Tdarr

To use the AV1 flow, you need to import it into Tdarr. The JSON file for the AV1 flow can be found [here](av1_flow_intel_arc.json). Use the lastest version, right now is v2 for better quality.

1. **Adding a New Flow**: In Tdarr, click on "Flows" at the top of the interface, then click the "Flow+" button to add a new flow.

    ![Adding a New Flow in Tdarr](https://i.imgur.com/nLzQi1b.png)

2. **Scroll to the Bottom**: Scroll to the very bottom of the page to find the import option. It can be easy to miss, so make sure you scroll all the way down.

    ![Scroll to Find the Import Option](https://i.imgur.com/hmYNetQ.png)

3. **Import the Flow**: Copy the exact JSON content from the [AV1 flow JSON file](av1_flow_v3.json) and paste it into the import field.

    ![Copy the JSON Content](https://i.imgur.com/Qe13kYg.png)

4. **Enabling the Flow for Libraries**: After importing the flow, you need to enable it for each library. Go to the "Library" tab in Tdarr, click "Transcode Options" for each library, and change the transcode option from "Classic Plugin" to "AV1" or whatever you named the flow.

    **Note**: This step is crucial as the flow will not work until it is applied to the libraries.

---

## Optimizing AV1 Encoding Settings

To get the best results with AV1 encoding, consider the following tips:

1. **Balancing Quality and Compression**: Adjust the CRF (Constant Rate Factor) and bit rate settings to find the right balance between video quality and file size. A lower CRF value will increase quality but also file size, while a higher CRF value will reduce quality but save more space.
  
2. **Hardware Acceleration**: Ensure that your Intel ARC GPU is being utilized for hardware-accelerated encoding. This can significantly speed up the process and reduce the load on your CPU.

3. **Testing Settings**: Run a few test encodes with different settings to determine what works best for your library. Different types of content may require different settings to achieve optimal results.

---

## Tdarr Node Killer Script (Totally Optional & Not Required)

### Overview

The Tdarr Node Killer Script is designed to manage your GPU resources between Plex and Tdarr efficiently. It ensures that when Plex starts transcoding, the Tdarr node using the same GPU is automatically stopped, preventing any conflicts.

You can find the script [here](https://github.com/plexguide/tdarr-av1-scripts/blob/main/tdarr_node_killer.sh).

### Script Behavior

### Changes 
v1: Initial Script
v2: Changed to Use Tautulli API for Plex Monitoring

1. **Monitoring Plex**: This script interfaces with Tautulli's API to determine if Plex is Transcoding. 
2. **3 Second Check Cycle**: Every 3 seconds, the script checks in with Tautulli to see if Plex is transcoding.
   - If nothing is transcoding, the script checks in every three seconds.
   - If Plex is transcoding via Tautulli's moniotring, this script will killer your Tdarr Node so the GPU can be dedicated soley for Plex.
   - When Plex is no longer transcoding after a 180 second check, this script will restart your Tdarr Node. The purpose of the 180 seconds is to ensure the script does not constantly bring your Tdarr Node - up and down in a short period.

This setup allows you to put the GPU back to work when Plex is idle, while ensuring Plex users always get priority when transcoding is required.

### Step-by-Step Implementation for Unraid

1. **Tdarr Node Running, No Plex Transcoding**

    ![Tdarr Node Running, No Plex Transcoding](https://i.imgur.com/PHRITk0.png)

    **Explanation**: The Tdarr node is running, and Plex is not currently transcoding any videos. This means Tdarr is using the GPU resources for video processing tasks.

2. **Script Monitoring for Plex Transcoding**

    ![Script Monitoring, No Transcoding Detected](https://i.imgur.com/tveaVA5.png)

    **Explanation**: The script continuously checks if Plex is transcoding. At this point, no transcoding is detected, so Tdarr continues using the GPU.

3. **Plex User Starts Transcoding**

    ![Plex User Starts Transcoding](https://i.imgur.com/AT6hCUV.png)

    **Explanation**: A Plex user starts watching a video, causing Plex to begin transcoding. This might happen if the video is in a format like AV1, H.264, or H.265, which requires transcoding for older devices or specific user settings.

4. **Script Detects Plex Transcoding, Stops Tdarr Node**

    ![Script Detects Plex Transcoding, Stops Tdarr Node](https://i.imgur.com/iwob8yB.png)

    **Explanation**: The script detects that Plex is transcoding and stops the Tdarr node. This action frees up the Intel ARC GPU so that Plex can use it exclusively for transcoding.

5. **Tdarr Node Is Stopped**

    ![Tdarr Node Stopped](https://i.imgur.com/KzdXHKf.png)

    **Explanation**: Inside Tdarr, you can see that the node has been stopped by the script. This ensures that Plex has full access to the GPU for efficient transcoding.

6. **Tdarr Node Dead**

    ![Tdarr Node Dead](https://i.imgur.com/4gIzOkW.png)

    **Explanation**: The Tdarr node is completely stopped, ensuring that Plex has exclusive access to the GPU.

### Script Behavior After Plex Transcoding Stops

The script doesn't immediately restart the Tdarr node after Plex stops transcoding. Instead, it checks every 5 seconds for 5 minutes to ensure that Plex isn't going to start transcoding again. This prevents the Tdarr node from constantly stopping and starting, which could be inefficient.

1. **Countdown Before Restarting Tdarr Node**

    ![Countdown Before Restarting Tdarr Node](https://i.imgur.com/59AGRlv.png)

    **Explanation**: The script is counting down, checking every 5 seconds to see if Plex starts transcoding again. If Plex does start, the timer resets, ensuring that the Tdarr node stays off as long as Plex needs the GPU.

2. **Tdarr Node Restarted After 5 Minutes**

    ![Tdarr Node Restarted](https://i.imgur.com/ExHsAQI.png)

    **Explanation**: After 5 minutes with no Plex transcoding detected, the script restarts the Tdarr node. The process then continues to check if Plex starts transcoding, so the node can be stopped again if needed.

3. **Tdarr Node Coming Back Online**

    ![Tdarr Node Coming Back Online](https://i.imgur.com/TTPVyt0.png)

    **Explanation**: Inside Tdarr, you can see that the node is coming back online after being restarted by the script.

4. **Tdarr Node Fully Online**

    ![Tdarr Node Fully Online](https://i.imgur.com/M1M2vSL.png)

    **Explanation**: The Tdarr node is now fully operational and visible on the dashboard. The script will continue to monitor Plex and manage the node as needed.

### Troubleshooting Common Issues

If you encounter issues during setup or operation, here are some common problems and solutions:

1. **Plex Not Using GPU for Transcoding**:
   - **Verify GPU Configuration**: Ensure the Intel ARC GPU is correctly added to the Plex Docker template and that the correct device path is used.
   - **Check Logs**: Review Plex logs for any errors related to GPU transcoding. This can help identify if Plex is defaulting to CPU transcoding due to a misconfiguration.
   - **Driver Issues**: Ensure that the necessary drivers for Intel ARC are installed and up to date. If using Unraid, make sure the Intel GPU TOP plugin is correctly installed and running.

2. **Tdarr Node Not Restarting After Plex Stops Transcoding**:
   - **Script Debugging**: Run the script manually and monitor the output to ensure it’s detecting the end of Plex transcoding correctly.
   - **Check for Conflicting Processes**: Ensure that no other processes are interfering with the Tdarr node or preventing it from restarting.

3. **High CPU Usage During Transcoding**:
   - **HDR Tone Mapping**: Verify that HDR tone mapping is disabled in Plex settings if you're using the Intel ARC GPU. This is a common cause of high CPU usage as Plex defaults to CPU transcoding for HDR content.
   - **Check GPU Utilization**: Use the GPU Statistics plugin to monitor GPU utilization and ensure the GPU is being used efficiently.

---

## Experimental: Running the Script on Other Operating Systems

While this script is designed to work seamlessly on Unraid, it can technically work on any operating system that supports Docker and systemd services. The steps provided below can be adapted for use on systems like Ubuntu, CentOS, or any other Linux distribution that uses systemd.

### Step-by-Step Implementation for Other OSes

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

3. **Create a Service File**: Create a service file for the script:

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

## Backup and Recovery Tips

Before making significant changes to your Unraid setup, Plex configurations, or Docker containers, it's essential to create backups. Here are some tips:

1. **Backup Plex Configurations**:
   - Use the built-in Plex backup tools to save your library metadata, watch history, and other settings.
   - Regularly back up the Plex configuration folder (`/config`) to ensure you can restore your setup if needed.

2. **Backup Docker Containers**:
   - Create backups of your Docker container templates in Unraid. This makes it easy to redeploy containers with the same settings if something goes wrong.
   - Consider using Unraid’s built-in backup features or plugins like CA Backup/Restore Appdata to automate this process.

3. **Backup Unraid Configuration**:
   - Regularly back up your Unraid flash drive. This contains your Unraid license, configuration, and other critical settings.
   - Use the Unraid GUI to download a backup of your flash drive, and store it in a safe location.

4. **Recovery Testing**:
   - Periodically test your backups by restoring them to ensure they work as expected. This is crucial for verifying that your backups are reliable.

By following these backup and recovery tips, you can ensure that your setup remains stable and that you can recover quickly from any issues.

---

## Summary

The Tdarr Node Killer Script is designed to intelligently manage GPU resources between Plex and Tdarr. By monitoring Plex transcoding activity and controlling the Tdarr node, the script ensures that your Intel ARC GPU is used efficiently. This guide provides a visual walkthrough of the process, making it easy for beginners to understand how the script works and how to configure it for their own use.
