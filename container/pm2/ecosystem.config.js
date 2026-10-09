module.exports = {
  apps: [
    {
      name: "docs",
      script: "/usr/bin/python3",
      args: "-m http.server 8080 --directory /var/www/docs",
      out_file: "/dev/shm/docs.log",
      error_file: "/dev/shm/docs.err",
      restart_delay: 5000,
      autorestart: true
    }
  ]
};