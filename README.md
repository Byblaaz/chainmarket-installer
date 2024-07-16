# Project Setup and Installation

This repository contains the necessary files to set up and run your Docker containers with a pre-configured environment. Follow the instructions below to get started.

## Prerequisites

Before you begin, ensure you have the following installed on your system:

- Git

## Installation Steps

### 1. Clone the Repository

Clone this repository to your local machine using the following command:

```sh
git clone git@github.com:Byblaaz/chainmarket-installer.git
```

### 2. Navigate to the Directory

Navigate to the directory where the repository has been cloned:

```sh
cd chainmarket-installer
```

### 3. Make the Installer Executable

Make the installer script executable by running the following command:

```sh
chmod +x installer.sh
```

### 4. Run the Installer

Run the installer script to set up Docker and other dependencies:

```sh
./installer.sh
```

### 5. Follow On-Screen Instructions

Follow the on-screen instructions to complete the installation process.

### 6. Check Synchronization

To verify if everything is synchronized correctly, you can use the following command to display the latest logs of the Polo1 container:

```sh
docker logs --tail 1 mark1
```

### Result
{ message: 'success', clientIP: 'x' }


### Troubleshoot

To stop the containers use
```sh 
docker stop polo1 mark1
```



