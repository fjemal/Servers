#!/bin/bash

echo "Current python version:"

python --version

echo "installing virtualenv so we can give django its own version of python"

# here you can install with updates or without updates.  To install python pip with a full kernel upgrade (not somthing you would do in prod, but
# definately somthing you might do to your testing or staging server: sudo yum update

# for a prod install (no update)

# this adds the noarch release reposatory from the fedora project, wich contains python pip
# python pip is a package manager for python...

rpm -iUvh https://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-9.noarch.rpm

yum -y install python-pip

# Now we're installing virtualenv, which will allow us to create a python installation and environment, just for our Django server
pip install virtualenv

cd /opt
# we're going to install our django libs in /opt, often used for optional or add-on.  /usr/local is also a perfectly fine place for new apps
# we want to make this env accisible to the ec2-user at first, because we don't want to have to run it as root.

mkdir django
#allows permissions to the user
chown -R yojetoga django

sleep 5

cd django

virtualenv django-env

echo "activating virtualenv"

source /opt/django/django-env/bin/activate

echo "to switch out of virtualenv, type deactivate"

echo "now using:"

which python

#changing permissions to the user
chown -R yojetoga /opt/django

echo "installing django"
 
pip install django


echo "django admin is version:"

django-admin --version

django-admin startproject project1

echo "here's our new django project dir"

tree project1

echo "go to https://docs.djangoproject.com/en/1.10/intro/tutorial01/"

#obtain external IP
Ip=$(curl icanhazip.com)

#set the IP into the django setting
sed -i -e "28s/.*/ALLOWED_HOSTS = [\'$Ip\']/" /opt/django/project1/project1/settings.py

#make initial migrations using sqllite
cd /opt/django/project1
/opt/django/django-env/bin/python manage.py makemigrations
/opt/django/django-env/bin/python manage.py migrate
echo yes | /opt/django/django-env/bin/python manage.py collectstatic

deactivate

#editing Http.config to allow django imigration and mod_wsgi
echo '# WSGI config \
WSGIScriptAlias "/" "/opt/django/project1/project1/wsgi.py" \
WSGIPythonPath "/opt/django/project1:/opt/django/django-env/lib/python2.7/site-packages" \
 \
Alias /robots.txt /opt/django/project1/static/robots.txt \
#Alias /favicon.ico /path/to/mysite.com/static/favicon.ico \
 \
#Alias /media/ /path/to/mysite.com/media/ \
Alias /static/ /opt/django/project1/static/ \
#Alias /static /path/to/mysite.com/static/ \
 \
<Directory /opt/django/project1/static > \
Require all granted \
</Directory> \
 \
<Directory /path/to/mysite.com/media> \
Require all granted \
</Directory> \
 \
<Directory /opt/django/project1/project1 > \
<Files wsgi.py > \
Require all granted \
</Files> \
</Directory>' >> /etc/httpd/conf/httpd.conf

sed -i "102s/<Directory \/>/#<Directory \/>/" /etc/httpd/conf/httpd.conf
sed -i "103s/    AllowOverride none/#    AllowOverride none/" /etc/httpd/conf/httpd.conf
sed -i "104s/    Require all denied/#    Require all denied/" /etc/httpd/conf/httpd.conf
sed -i "105s/<\/Directory>/#<\/Directory>/" /etc/http/conf/httpd.conf

#editing the setting of Django project and allowing to access the the postgres
Ipspost=ip

sed -i "s/        'ENGINE': 'django.db.backends.sqlite3',/        'ENGINE': 'django.db.backends.postgresql_psycopg2',/g" /opt/django/project1/project1/settings.py
sed -i "s/        'NAME': os.path.join(BASE_DIR, 'db.sqlite3'),/        'NAME': 'project1',/g" /opt/django/project1/project1/settings.py
sed -i "80s/}/'USER': 'yolman',\n\t}/" /opt/django/project1/project1/settings.py
sed -i "81s/}/'PASSWORD': '123456',\n\t}/" /opt/django/project1/project1/settings.py
sed -i "82s/}/'HOST': '$Ipspost',\n\t}/" /opt/django/project1/project1/settings.py
sed -i "83s/}/'PORT': '5432',\n\t}/" /opt/django/project1/project1/settings.py

#prepare django for postgresql integration -- install postgres dev packages
source /opt/django/django-env/bin/activate
sudo yum -y install python-devel postgresql-devel
sudo yum -y install gcc

#install psycopg2 to allow us to use the project1 database on postgres server
pip install psycopg2

#migrate databasae 
cd /opt/django/project1
python manage.py makemigrations 
python manage.py migrate

#create superuser for admin login
cd /opt/django/project1
#/opt/django/django-env/bin/python manage.py createsuperuser
#manage.py docs for automataing
echo "from django.contrib.auth.models import User; User.objects.create_superuser('Yolman', 'yojetoga@gmail.com', 'torrez')" | python manage.py shell

deactivate

#allow django to connect to the db on httpd <--- solves issue with django being able to reconnect to the db
sudo setsebool -P httpd_can_network_connect_db on

#restart httpd service
sudo systemctl restart httpd
