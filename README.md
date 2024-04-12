# apcupsd plus apcupsd-cgi
Docker - APC UPS Power Management daemon plus Web Interface (from nginx:latest, fcgiwrap, apcupsd-cgi)

*Requirements:*

This is the APC UPS Power Management daemon plus Web Interface, so it is necessary to have an [APC UPS](https://www.apc.com/) that supports monitoring (USB cable or network). 
You have to install the [apcupsd daemon](http://www.apcupsd.org/) on the host machine(s). There are two options here, either install apcupsd directly on each host that has a UPS connected to it, or in a container on each of those hosts. If you have multiple UPS units, don't already have apcupsd installed on the host, and prefer to use Docker and Portainer when possible:

## apcupsd
### *Portainer Stacks (container-based) installation of the apcupsd daemon:*

```yml
version: '4.0'
services:
  apcupsd:
    image: localhost/apcupsd:latest
    hostname: apcupsd_ups # Use a unique hostname here for each apcupsd instance, and it'll be used instead of the container number in apcupsd-cgi and Email notifications.
    devices:
      - /dev/usb/hiddev0 # This device needs to match what the APC UPS on your APCUPSD_MASTER system uses -- Comment out this section on APCUPSD_SLAVES
    ports:
      - 3551:3551
    environment:
      - UPSNAME=${UPSNAME} # Sets a name for the UPS (1 to 8 chars), that will be used by System Tray notifications, apcupsd-cgi and Grafana dashboards
      
      # Environment variables for connectivity other than USB, including for slaves that aren't directly connected to a UPS:
#      - UPSCABLE=${UPSCABLE} # Usually doesn't need to be changed on system connected to UPS. (default=usb) On APCUPSD_SLAVES set the value to ether
#      - UPSTYPE=${UPSTYPE} # Usually doesn't need to be changed on system connected to UPS. (default=usb) On APCUPSD_SLAVES set the value to net
#      - DEVICE=${DEVICE} # Use this only on APCUPSD_SLAVES to set the hostname or IP address of the APCUPSD_MASTER with the listening port (:3551)

      # Environment variables for monitoring and shutdown of UPS connected device(s), and the shutdown of the UPS itself:
#      - POLLTIME=${POLLTIME} # Interval (in seconds) at which apcupsd polls the UPS for status (default=60)
#      - ONBATTERYDELAY=${ONBATTERYDELAY} # Sets the time in seconds from when a power failure is detected until an onbattery event is initiated (default=6)
#      - BATTERYLEVEL=${BATTERYLEVEL} # Sets the daemon to send the poweroff signal when the UPS reports a battery level of x% or less (default=5)
#      - MINUTES=${MINUTES} # Sets the daemon to send the poweroff signal when the UPS has x minutes or less remaining power (default=5)
#      - TIMEOUT=${TIMEOUT} # Sets the daemon to send the poweroff signal when the UPS has been ON battery power for x seconds (default=0)
#      - KILLDELAY=${KILLDELAY} # If non-zero, sets the daemon to attempt to turn the UPS off x seconds after sending a shutdown request (default=0)

      # Environment variable for conducting a UPS selftest at a timed interval:
#      - SELFTEST=${SELFTEST} # Sets the daemon to ask the UPS to perform a self test every x hours (default=336)

      # Use these two environment variables to list the slaves that will be connected to this master:
#      - APCUPSD_HOSTS=${APCUPSD_HOSTS} # If this is the MASTER, then enter the APUPSD_HOSTS list here, including this system (space separated)
#      - APCUPSD_NAMES=${APCUPSD_NAMES} # Match the order of this list one-to-one to APCUPSD_HOSTS list, including this system (space separated)

      # Environment variable for setting your local timezone in lieu of UTC:
      - TZ=${TZ}
      
      # Environment variable to update apcupsd scripts and .conf even if a persistent host data directory is being bound to the container.
      # Normally scripts are not overwritten once saved in you bound directory. They are updated occasionally though, so don't let then get out-of-date.
      # You can leave this as true if you've done no manual editing of the scripts
      - UPDATE_SCRIPTS=${UPDATE_SCRIPTS} # Set to true if you'd like all the apcupsd scripts and .conf file to be overwritten with the latest versions
      
      # Environment variables to recieve notifications via Gmail SMTP Email or SMS related to power failure events or urgent UPS maintenance
      # No need to use your personal Gmail account for SMTP. Setup a new one along with 2FA and an "app password" for Proxmox.
      # You can still send notifications to your personal account if you like, or to SMS via carrier's Email to SMS gateway.
      - SMTP_GMAIL=${SMTP_GMAIL} # Gmail account (with 2FA enabled) to use for SMTP
      - GMAIL_APP_PASSWD=${GMAIL_APP_PASSWD} # App password for apcupsd from Gmail account being used for SMTP
      - NOTIFICATION_EMAIL=${NOTIFICATION_EMAIL} # The Email account to receive on/off battery messages and other notifications (Any valid Email will work)
      - POWER_RESTORED_EMAIL=${POWER_RESTORED_EMAIL} # Set to true if you'd like an Email notification when power is restored after UPS shutdown
      
      # Environment variables related to waking sytems after being shutdown during a power failure event. Requires configured bnhf/wolweb container:
      - WOLWEB_HOSTNAMES=${WOLWEB_HOSTNAMES} # Space seperated list of hostnames names to send WoL Magic Packet to on startup
      - WOLWEB_PATH_BASE=${WOLWEB_PATH_BASE} # Everything after http:// and before the /hostname required to wake a system with WoLweb e.g. raspberrypi6:8089/wolweb/wake
      - WOLWEB_DELAY=${WOLWEB_DELAY} # Value to use for "sleep" delay before sending a WoL Magic Packet to WOLWEB_HOSTNAMES in seconds
      
      # Environment variables related to shutting down one or more Proxmox nodes. All VMs and CTs must be shutdown first -- which can be done by setting them up as apcupsd slaves.
      # Create a "shutdwon" pve realm user with "shutdown" role of Sys.PowerMgmt only. Then create API token for that user.
      # You can either list a matching number hosts, nodes and tokens below -- or if it can all be done through the same host and token list those along with multiple nodes:
      - PVE_SHUTDOWN_HOSTS=${PVE_SHUTDOWN_HOSTS} # Ordered list of pve hostnames (or IPs) to be used for API shutdown. Used with matching lists of $PVE_SHUTDOWN_NODES and $PVE_SHUTDOWN_TOKENS
      - PVE_SHUTDOWN_NODES=${PVE_SHUTDOWN_NODES} # Ordered list of pve nodes. Used with matching lists of $PVE_SHUTDOWN_HOSTS and $PVE_SHUTDOWN_TOKENS
      - PVE_SHUTDOWN_TOKENS=${PVE_SHUTDOWN_TOKENS} # Ordered list of pve API tokens with secrets in the form <username>@<node>!<api_token>=<api_secret>
      
    # The system_bus_socket binding is always required for host computer shutdowns. The data directory can be a basic binding as shown, or use a Docker Volume if preferred.
    volumes:
      - /var/run/dbus/system_bus_socket:/var/run/dbus/system_bus_socket # Required to support host shutdown from the container
      - /data/apcupsd:/etc/apcupsd # /etc/apcupsd can be bound to a directory or a docker volume
    
# If you prefer to use Docker Volumes instead of directory bindings, uncomment below as required.
# volumes: # Use this section for volume bindings only
#   config: # The name of the stack will be appended to the beginning of this volume name, if the volume doesn't already exist
#     external: true # Use this directive if you created the docker volume in advance
```
*All environment variables are optional for the above (or hardcode values into compose). At least UPSNAME is recommended though:*
 
```console
UPSNAME=${UPSNAME}
UPSCABLE=${UPSCABLE}
UPSTYPE=${UPSTYPE}
DEVICE=${DEVICE}
POLLTIME=${POLLTIME} 
ONBATTERYDELAY=${ONBATTERYDELAY}
BATTERYLEVEL=${BATTERYLEVEL}
MINUTES=${MINUTES}
TIMEOUT=${TIMEOUT}
KILLDELAY=${KILLDELAY}
SELFTEST=${SELFTEST} 
APCUPSD_HOSTS=${APCUPSD_HOSTS}
APCUPSD_NAMES=${APCUPSD_NAMES}
TZ=${TZ}
UPDATE_SCRIPTS=${UPDATE_SCRIPTS}
SMTP_GMAIL=${SMTP_GMAIL}
GMAIL_APP_PASSWD=${GMAIL_APP_PASSWD}
NOTIFICATION_EMAIL=${NOTIFICATION_EMAIL}
POWER_RESTORED_EMAIL=${POWER_RESTORED_EMAIL}
WOLWEB_HOSTNAMES=${WOLWEB_HOSTNAMES}
WOLWEB_PATH_BASE=${WOLWEB_PATH_BASE}
WOLWEB_DELAY=${WOLWEB_DELAY}
PVE_SHUTDOWN_HOSTS=${PVE_SHUTDOWN_HOSTS}
PVE_SHUTDOWN_NODES=${PVE_SHUTDOWN_NODES}
PVE_SHUTDOWN_TOKENS=${PVE_SHUTDOWN_TOKENS}
```

## apcupsd-cgi
The docker image is Debian 11 (Bullseye) based, with nginx-light as web server, fcgiwrap as cgi server and obviously apcupsd-cgi. 

Apcupsd-cgi is configured to search and connect to the apcupsd daemon on the host machine IP via the standard port 3551. Nginx is configured to connect with fcgiwrap (CGI server) and to serve multimon.cgi directly on port 80. The container exposes port 80, but can be remapped as required -- I use port 3552.

### *Portainer Stacks (container-based) installation of apcupd-cgi:*

```yml
version: '4.0'
services:
  apcupsd-cgi:
    image: localhost/apcupsd-cgi:latest
    dns_search: localdomain # Set to your LAN's domain name (often local or localdomain), this should help with local DNS resolution of hostnames
    ports:
      - 3552:80
    environment:
      - UPSHOSTS=${UPSHOSTS} # Ordered list of hostnames or IP addresses of UPS connected computers (space separated, no quotes)
      - UPSNAMES=${UPSNAMES} # Matching ordered list of location names to display on status page (space separated, no quotes)
      - TZ=${TZ} # Timezone to use for status page -- UTC is the default
      - DASHBOARD_PROVISION=${DASHBOARD_PROVISION} # Set to true if you'd like this container to place data files (in advance) for use with the companion Grafana Dashboard
    volumes:
      - /data/apcupsd-cgi:/etc/apcupsd
      - /data/telegraf:/etc/telegraf # Only required if you'd like this container to place data files (in advance) for use with the companion Grafana Dashboard
      - /data/grafana/provisioning:/etc/grafana/provisioning # Only required if you'd like this container to place data files (in advance) for use with the companion Grafana Dashboard
```
*Environment variables required for the above (or hardcode values into compose):*

    UPSHOSTS (List of hostnames or IP addresses for computers with connected APC UPSs. Space separated without quotes.)
    UPSNAMES (List of names you'd like used in the WebUI. Order must match UPSHOSTS. Space separated without quotes.)
    TZ (Timezone for apcupsd-cgi to use when displaying information about individual UPS units)
    DASHBOARD_PROVISION (Set to true to create data directories and pre-provision a Grafana Dashboard to monitor your APC UPS units -- see TIG stack below )
    
Here's an example of what your Portainer Stack would look like:

![screencapture-raspberrypi10-2023-05-08-10_17_51](https://user-images.githubusercontent.com/41088895/236878013-aa67aedd-c800-4ed1-9959-61f0785ceb92.png)

If you want to customize the image, you have to clone the repository on your system:
```
git clone https://github.com/bnhf/apcupsd-admin-plus.git
```
edit the files and recreate a new image
```
sudo docker build -t yourname/apcupsd-cgi .
```
## apcupsd-cgi
Enter the application at address http://your_host_IP:3552

Here's what it looks like running in an Organizr window with Portainer, Cockpit and OpenVPN Admin Plus available:

![screenshot-raspberrypi10-2023 05 07-11_42_01](https://user-images.githubusercontent.com/41088895/236878302-69cad775-555c-4ca9-9189-249fc4a685c1.png)

And drilling down on one of the UPS units for additional detail:

![screenshot-raspberrypi10-2023 01 19-14_50_25](https://user-images.githubusercontent.com/41088895/213570880-d6eb5980-2f98-4523-a530-0fa0c3da7832.png)

## Grafana Dashboard (pre-provision by deploying apcupsd-cgi first with indicated additional volumes and environment variable)

![screencapture-raspberrypi4-2023-06-04-11_55_46](https://github.com/bnhf/apcupsd-admin-plus/assets/41088895/181cfa81-666f-4e6f-b05d-6765174e60c8)

### *Portainer Stacks (container-based) installation of TIG stack to deploy APC UPS dashbaord :*

```yml
version: '4.0'
services:
  influxdb2:
    image: influxdb:latest
    ports:
      - 8086:8086
    volumes:
      - /data/influxdb2/data:/var/lib/influxdb2
      - /data/influxdb2/config:/etc/influxdb2
    environment:
      - DOCKER_INFLUXDB_INIT_MODE=${MODE} # Required, usually <setup>
      - DOCKER_INFLUXDB_INIT_USERNAME=${USERNAME} # Usually <admin> and this will be the username for Grafana as well
      - DOCKER_INFLUXDB_INIT_PASSWORD=${PASSWORD} # Whatever you want for a password for InfluxDB and Grafana
      - DOCKER_INFLUXDB_INIT_ORG=${ORG} # Required, make something up if you're not part of an organization
      - DOCKER_INFLUXDB_INIT_BUCKET=${BUCKET} # Required, usually <telegraf>
      - DOCKER_INFLUXDB_INIT_RETENTION=${RETENTION} # Required, usually <1w>
      - DOCKER_INFLUXDB_INIT_ADMIN_TOKEN=${ADMIN_TOKEN} # Required, make up a token or use https://randomkeygen.com CodeIgniter Encryption Keys
    
  telegraf:
    image: telegraf:latest
    pid: 'host'
    ports:
      - 8092:8092
      - 8094:8094
      - 8125:8125
    environment:
      - HOST_PROC=/host/proc
      - HOST_SYS=/host/sys
      - HOST_ETC=/host/etc
      - DOCKER_INFLUXDB_INIT_ORG=${ORG}
      - DOCKER_INFLUXDB_INIT_BUCKET=${BUCKET}
      - DOCKER_INFLUXDB_INIT_ADMIN_TOKEN=${ADMIN_TOKEN}
      - UPS1=${UPS1}
      - UPS2=${UPS2} # Optional if you have more than one UPS
      - UPS3=${UPS3} # Optional if you have more than one UPS
      - UPS4=${UPS4} # Optional if you have more than one UPS
      - UPS5=${UPS5} # Optional if you have more than one UPS
      - UPS6=${UPS6} # Optional if you have more than one UPS
      - UPS7=${UPS7} # Optional if you have more than one UPS
      - UPS8=${UPS8} # Optional if you have more than one UPS
    volumes:
      - /data/telegraf/telegraf.conf:/etc/telegraf/telegraf.conf:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /sys:/host/sys:ro
      - /proc:/host/proc:ro
      - /etc:/host/etc:ro
    
  grafana8:
    image: grafana/grafana:latest
    ports:
      - 3000:3000
    user: '0:0'
    environment:
      - GF_SECURITY_ADMIN_USER=${USERNAME}
      - GF_SECURITY_ADMIN_PASSWORD=${PASSWORD}
      - GF_SECURITY_ALLOW_EMBEDDING=true # Allows iFrame embedding in Organizr for example
      - DOCKER_INFLUXDB_INIT_ORG=${ORG}
      - DOCKER_INFLUXDB_INIT_BUCKET=${BUCKET}
      - DOCKER_INFLUXDB_INIT_ADMIN_TOKEN=${ADMIN_TOKEN}
    volumes:
      - /data/grafana:/var/lib/grafana
      - /data/grafana/provisioning:/etc/grafana/provisioning
```

*Environment variables required for the above (or hardcode values into compose):*

```console
MODE=setup
USERNAME=admin
PASSWORD=
ORG=
BUCKET=telegraf
RETENTION=1w
ADMIN_TOKEN=
UPS1=<hostname or IP>:3551
UPS2=<hostname or IP>:3551
UPS3=<hostname or IP>:3551
UPS4=<hostname or IP>:3551
UPS5=<hostname or IP>:3551
UPS6=<hostname or IP>:3551
```    
