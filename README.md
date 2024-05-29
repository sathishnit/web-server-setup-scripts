# Web Server Setup Scripts

This repository contains scripts to set up a web server on an Azure Compute instance running Ubuntu Minimal Server 24.04. The setup includes Apache, Nginx, MySQL, PHP 8.3, Let's Encrypt SSL certificates, and WordPress. The project has evolved through several versions, incorporating new features and improvements at each step.

## Versions

### Version 1: Initial Setup Script

- **Features:**
  - Prompts for domain name or IP address, email for SSL certificate registration, and whether to request a wildcard SSL certificate.
  - Updates and upgrades the system.
  - Installs Apache2, MySQL Server, and PHP 8.3 with necessary modules.
  - Configures Apache to serve a simple PHP info page.

- **Files:**
  - `setup_server.sh`
  - `sse.php`
  - `index.html`

### Version 2: Added MySQL Secure Installation and Real-Time Output

- **Features:**
  - Adds secure installation of MySQL Server.
  - Implements Server-Sent Events (SSE) for real-time script output in the web interface.

- **Files:**
  - `setup_server.sh`
  - `sse.php`
  - `index.html`

### Version 3: WordPress Setup with Secure wp-admin and SSL Configuration

- **Features:**
  - Downloads and sets up WordPress.
  - Creates a secure `wp-config.php` file with database credentials.
  - Enables SSL for the WordPress admin area.
  - Configures Apache to listen on port 8080 and Nginx as a reverse proxy with SSL.

- **Files:**
  - `setup_server.sh`
  - `sse.php`
  - `index.html`

## Setup Instructions

### Prerequisites

- An Azure Compute instance running Ubuntu Minimal Server 24.04.
- Domain name pointing to the server.
- SSH access to the server.

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/your-username/web-server-setup-scripts.git
   cd web-server-setup-scripts
2. Make the setup script executable:
   chmod +x setup_server.sh
3. Open index.html in a web browser, fill in the required details, and run the script. The real-time output will be displayed on the web page.


   Usage
Running the Setup Script
Via Command Line:

bash
Copy code
./setup_server.sh <domain> <email> <yes|no>
Replace <domain> with your domain, <email> with your email address, and <yes|no> with whether you want a wildcard SSL certificate.

Via Web Interface:
Open index.html in a web browser, enter your domain and email, select whether you want a wildcard SSL certificate, and submit the form. The output will be displayed in real-time on the web page.

Script Output
The script provides real-time output updates using Server-Sent Events (SSE). The output can be viewed in the web interface.

Security Considerations
The MySQL root password is kept blank during the secure installation. Adjust the script to set a strong password if needed.
The wp-config.php file is configured to force SSL for the WordPress admin area.
Contributions
Contributions are welcome! Please fork the repository and create a pull request with your changes.

License
This project is licensed under the MIT License. See the LICENSE file for details.

Acknowledgments
Inspired by the need to automate web server setups efficiently and securely.
Thanks to the open-source community for providing essential tools and libraries.
markdown
Copy code

### Usage Notes

- **Replace** `https://github.com/your-username/web-server-setup-scripts.git` with the actual URL of your GitHub repository.
- **Ensure** the repository includes all necessary files (`setup_server.sh`, `sse.php`, `index.html`) for each version.

This `README.md` provides a clear overview of the project, its evolution, and how to use it. It guides use
