# Odoo Setup Automation Scripts

This repository contains a collection of Bash scripts designed to automate the setup and configuration of an Odoo environment. The scripts handle various tasks such as:

- Creating necessary directories and configurations for Odoo installations.
- Cloning specific Odoo repositories based on the version.
- Setting up virtual environments for running Odoo.
- Installing required dependencies for Odoo to run smoothly.
- Creating systemd service files to manage Odoo as a service.

These scripts are intended to streamline the Odoo installation and management process, making it easier to deploy and maintain Odoo instances on a server. Perfect for automating repetitive tasks and ensuring consistent environments.

## Prerequisites

Before running the scripts, ensure that you have the following installed and configured on your server:

- **Linux-based operating system** (e.g., Ubuntu, CentOS)
- **Python 3.12+**
- **pip** for Python package management
- **Git** for cloning Odoo repositories
- **Virtualenv** for managing Python environments
- **sudo** privileges to run commands with administrative rights
- **PostgreSQL**
- **Systemd** for managing the Odoo service (optional)

Ensure that these prerequisites are met to successfully run the scripts and deploy Odoo.
