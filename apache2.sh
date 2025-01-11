#!/bin/bash
sudo apt install apache2 -y
sudo systemctl enable apache2
sudo systemctl start apache2
sudo systemctl status apache2

echo "Welcome to TEKS Academy" > /var/www/html/index.html