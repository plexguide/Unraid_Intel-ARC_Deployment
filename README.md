# AV1 Flow + Enable Intel ARC + Tdarr Node Killer - Script Guide

# AV1 Flow and Tdarr Node Killer Script Guide

## Purpose

This guide aims to help users optimize their media libraries by using AV1 encoding and efficiently managing GPU resources between Plex and Tdarr. The AV1 Flow provides a highly efficient way to compress video files, saving significant storage space, while the Tdarr Node Killer Script ensures that your Intel ARC GPU is dedicated to Plex when needed, without interrupting other processes.

### What You Will Accomplish

- **AV1 Encoding**: Learn how to use AV1 encoding to significantly reduce the size of your video files, freeing up storage space while maintaining video quality.
- **Efficient GPU Management**: Implement a script that automatically manages your GPU resources, ensuring that Plex has dedicated access to your Intel ARC GPU when it needs to transcode video, without interrupting Tdarr's video processing tasks.
- **Optimized Media Library**: By following this guide, you will be able to compress a large media library, potentially reducing a 300TB library to 75-100TB, making it easier to manage and store.

### Why This Is Helpful

For users with large media libraries, storage space can quickly become an issue. The AV1 Flow provides an effective solution by drastically reducing the size of your video files. Additionally, the Tdarr Node Killer Script ensures that your Intel ARC GPU is used efficiently, preventing conflicts between Plex and Tdarr and ensuring that Plex users experience smooth, uninterrupted playback.

---

## AV1 Encoding Flow (Compatible with Intel ARC GPUs)

![AV1 Flow](https://i.imgur.com/FiFVxgT.png)

### What is the AV1 Flow?

The AV1 encoding flow is a process that converts video data into the AV1 format, known for its high efficiency and excellent compression. The flow involves:

1. **Source**: Your original video file.
2. **Input Processing**: Preparing the video by adjusting resolution, color space, and more.
3. **Encoding**: The AV1 encoder compresses the video data, making the file smaller without losing too much quality.
4. **Output**: The final, compressed AV1 video file is ready for streaming or storage.

**Note:** This flow should work on any operating system that has an Intel ARC GPU card. You just need to ensure that the ARC GPU is exposed in your Tdarr Docker container.

---

## Tdarr Node Killer Script Overview (Designed for Unraid, Works on Any OS)

This section explains how the Tdarr Node Killer Script works to manage your GPU resources, ensuring that Plex can have dedicated access when needed.

**Note:** While this script is designed to work seamlessly on Unraid, it can technically work on any operating system as long as you create a service. An experimental service script for Ubuntu is provided at the end of this guide.

### Prerequisites for Unraid

Before adding the Tdarr Node Killer Script, ensure that you have installed the [User Scripts] plugin by Andrew. This plugin is essential for running scripts on Unraid.

![User Scripts Plugin](https://i.imgur.com/JA90q6x.png)

Once the plugin is installed, set the script to run at "First Array Start Only." This setting ensures that the script starts with the array and continues to run. If it's determined that the script stops when the array is stopped, adjust it to "Start of Array Every Time."

![Set Script at First Array Start](https://i.imgur.com/MpG4lP8.png)

**Note:** Ignore the other two nodes in the photos. The selected node is dedicated to Plex. The purpose of this setup is to ensure that the GPU is put to work without disrupting Plex users. There are two ARC 380 GPUs (one dedicated to Plex) and one ARC 310 GPU. The ARC 380 GPUs can handle up to 7 streams each for Tdarr, while the ARC 310 handles up to 5 streams at a time.

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

## Tdarr Node Killer Script Behavior

### Step 1: Tdarr Node Running, No Plex Transcoding

![Tdarr Node Running, No Plex Transcoding](https://i.imgur.com/PHRITk0.png)

**Explanation**: The Tdarr node is running, and Plex is not currently transcoding any videos. This means Tdarr is using the GPU resources for video processing tasks.

### Step 2: Script Monitoring for Plex Transcoding

![Script Monitoring, No Transcoding Detected](https://i.imgur.com/tveaVA5.png)

**Explanation**: The script continuously checks if Plex is transcoding. At this point, no transcoding is detected, so Tdarr continues using the GPU.

### Step 3: Plex User Starts Transcoding

![Plex User Starts Transcoding](https://i.imgur.com/AT6hCUV.png)

**Explanation**: A Plex user starts watching a video, causing Plex to begin transcoding. This might happen if the video is in a format like AV1, H.264, or H.265, which requires transcoding for older devices or specific user settings.

### Step 4: Script Detects Plex Transcoding, Stops Tdarr Node

![Script Detects Plex Transcoding, Stops Tdarr Node](https://i.imgur.com/iwob8yB.png)

**Explanation**: The script detects that Plex is transcoding and stops the Tdarr node. This action frees up the Intel ARC GPU so that Plex can use it exclusively for transcoding.

### Step 5: Tdarr Node Is Stopped

![Tdarr Node Stopped](https://i.imgur.com/KzdXHKf.png)

**Explanation**: Inside Tdarr, you can see that the node has been stopped by the script. This ensures that Plex has full access to the GPU for efficient transcoding.

### Step 6: Tdarr Node Dead

![Tdarr Node Dead](https://i.imgur.com/4gIzOkW.png)

**Explanation**: The Tdarr node is completely stopped, ensuring that Plex has exclusive access to the GPU.

---

## Script Behavior After Plex Transcoding Stops

The script doesn't immediately restart the Tdarr node after Plex stops transcoding. Instead, it checks every 5 seconds for 5 minutes to ensure that Plex isn't going to start transcoding again. This prevents the Tdarr node from constantly stopping and starting, which could be inefficient.

### Step 7: Countdown Before Restarting Tdarr Node

![Countdown Before Restarting Tdarr Node](https://i.imgur.com/59AGRlv.png)

**Explanation**: The script is counting down, checking every 5 seconds to see if Plex starts transcoding again. If Plex does start, the timer resets, ensuring that the Tdarr node stays off as long as Plex needs the GPU.

### Step 8: Tdarr Node Restarted After 5 Minutes

![Tdarr Node Restarted](https://i.imgur.com/ExHsAQI.png)

**Explanation**: After 5 minutes with no Plex transcoding detected, the script restarts the Tdarr node. The process then continues to check if Plex starts transcoding, so the node can be stopped again if needed.

### Step 9: Tdarr Node Coming Back Online

![Tdarr Node Coming Back Online](https://i.imgur.com/TTPVyt0.png)

**Explanation**: Inside Tdarr, you can see that the node is coming back online after being restarted by the script.

### Step 10: Tdarr Node Fully Online

![Tdarr Node Fully Online](https://i.imgur.com/M1M2vSL.png)

**Explanation**: The Tdarr node is now fully operational and visible on the dashboard. The script will continue to monitor Plex and manage the node as needed.

---

## Data Savings with AV1 Encoding

Running this setup with three ARC GPUs has shown significant data savings over two weeks. With AV1 encoding, a savings of 37TB was achieved, covering only 10-15% of the library.

![Data Savings](https://i.imgur.com/Saic5J4.png)

**Explanation**: AV1 encoding can drastically reduce storage needs. For example, a 300TB library could be reduced to 75-100TB, making it an efficient solution for large media libraries.

---

## Experimental: Running the Script as a Service on Ubuntu

If you're using a different operating system like Ubuntu, you can run this script as a service. Below is an experimental service script to help you set it up.

### Creating the Service

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

This will allow the script to run automatically on startup and ensure that it stays active in the background, just like it would on Unraid.

---

## Summary

The Tdarr Node Killer Script is designed to intelligently manage GPU resources between Plex and Tdarr. By monitoring Plex transcoding activity and controlling the Tdarr node, the script ensures that your Intel ARC GPU is used efficiently. This guide provides a visual walkthrough of the process, making it easy for beginners to understand how the script works and how to configure it for their own use.
