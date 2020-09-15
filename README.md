# Bits of Bash

This script aims to provide the user with a modular structure for creating interactive bash scripts.

Hopefully this will be useful for those who are getting started with bash scripting. This can help you to layout a function and log details such as command output and user input.

Sample functions include:

- System - Installs a few packages, then sets a bash alias for a quick manual system update.

- Database - Install a MariaDB, MySQL or Mongo database.

- Jitsi Meet - Install a Jitsi Meet server.

- SMB - Install a password protected SMB server.

- Wireguard - VPN server and client setup.

- SSH - Server install and client key generation.

Instead of having several scripts, simply create a function using the "bonesMalone" function as your guide. Once the function is complete, add an entry to the menu or submenu of your choice so that the option can be presented to the user. This script has samples of making menus using whiptail and dialog.
<br><br>

## Getting Started

As you would with all scripts you find on the internet, please read it to make sure you understand what the code does and how it would affect your system.

Tested on the following distros:

- Ubuntu 18.04, 20.04
- Debian 10.5

### Requirements/Dependencies

- sudo privileges.
- The package "dialog". The script will automatically install this for you if it is missing.

<br>

## Running the script

Use the command:

```
sudo bash bitsOfBash.sh
```

<br><br>
The first menu that is presented to you will set a global variable that represents your working environment. This is useful if you need to write a function that will perform an action based on the working environment. (eg. Using yum instead of apt.)
<br><img src="images/img01_scriptEnv.png" height = "300">

<br><br>
You will be asked to select a user. This will set the global variable that represents your working user. This is useful when creating functions that require a target user directory or setting the ownership of a file.
<br><img src="images/img02_userSelect.png" height = "300">

<br><br>
Menus are a great way to organize your functions. In the image below, the "Desktop" and "Server" options are submenus containing functions related to those environments.
<br><img src="images/img03_mainMenu.png" height = "300">

<br><br>
Below is a sample of a submenu that has a few of the functions I have in my personal script.
<br><img src="images/img04_subMenu.png" height = "300">

<br><br>

## Using the template bonesMalone

This is the basic format for the functions used in this script. Just a sample, not mandatory.

- Step 1 - Apply a start timestamp to the log file.
- Step 2 - Check if the global variable for debug mode has been set. This is useful for testing the flow of deeply nested menus and exiting to a specific point or menu.
- Step 3 - Run the intended commands.
- Step 4 - Check if the function call is a part of a chain of function calls. This simply means that the function will not pause execution and display an ending prompt. It will just continue to the next function in the chain.
- Step 5 - Apply an end timestamp to the log file.
  <br><img src="images/img05_bonesMalone.png" height = "300">

## Adding to a menu

Insert an entry into the relevant whiptail menu and switch statement.

<br><img src="images/img06_addToMenu.gif" height = "400">

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE.md](LICENSE) file for details.

## Credits

Jitsi Meet

- https://jitsi.github.io/handbook/docs/devops-guide/devops-guide-quickstart

Wireguard

- https://www.wireguard.com/quickstart/
- https://www.linuxbabe.com/ubuntu/wireguard-vpn-server-ubuntu
