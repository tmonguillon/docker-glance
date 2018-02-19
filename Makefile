build:
	docker build -t openstack-glance:master .
run:
	docker run -t -i -d --rm --hostname glance --name glance -p 19191:9191 -p 19292:9292 openstack-glance:master
clean:
	docker rm -f glance
