module.exports = {
  apps: [
    {
      name: "docs-portal",
      script: "/usr/bin/python3",
      args: "-m http.server 8080 --directory /var/www/oppo-docs",
      out_file: "/dev/shm/docs-portal.log",
      error_file: "/dev/shm/docs-portal.err",
      restart_delay: 5000,
      autorestart: true
    }
    /*
    // Pending binary provisioning (/usr/bin/omniroute)
    ,
    {
      name: "omniroute",
      script: "/usr/bin/omniroute",
      env: {
        PORT: 20128,
        DATA_DIR: "/var/lib/omniroute"
      },
      out_file: "/dev/shm/omniroute.log",
      error_file: "/dev/shm/omniroute.err",
      restart_delay: 3000,
      autorestart: true
    }
    */
      script: "/usr/bin/omniroute",
      env: {
        PORT: 20128,
        DATA_DIR: "/var/lib/omniroute"
      },
      out_file: "/dev/shm/omniroute.log",
      error_file: "/dev/shm/omniroute.err",
      restart_delay: 3000,
      autorestart: true
    }
  ]
};
