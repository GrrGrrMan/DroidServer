module.exports = {
  apps: [
    {
      name: "platform-docs",
      script: "/usr/bin/python3",
      args: "-m http.server 8080 --directory /var/www/oppo-docs",
      out_file: "/dev/shm/platform-docs.log",
      error_file: "/dev/shm/platform-docs.err",
      restart_delay: 5000,
      autorestart: true
    },
    {
      name: "app-docs",
      script: "/usr/bin/python3",
      args: "-m http.server 8081 --directory /var/www/oppo-app-docs",
      out_file: "/dev/shm/app-docs.log",
      error_file: "/dev/shm/app-docs.err",
      restart_delay: 5000,
      autorestart: true
    }
  ]
};