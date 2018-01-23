build:
	docker build -t openstack-glance:master .
run:
	docker run -t -i -d --rm --hostname glance --name glance openstack-glance:master bash
clean:
	docker rm -f glance
