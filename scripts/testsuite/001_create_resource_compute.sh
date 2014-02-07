#!/bin/sh

for i in $(seq 1 10); do
    idx=$(printf '%02d' $i)
    id=/myresources/compute/id${idx}
    echo "Creating resource "${id}

    (
	cat <<EOF
{
    "resources": [
	{
            "kind": "http://schemas.ogf.org/occi/infrastructure#compute",
	    "attributes": {
		"occi": {
		    "core": {
			"title": "Machine${idx}"
		    },
		    "compute": {
			"architecture": "x86",
			"cores": 1,
			"hostname": "pc${idx}",
			"memory": 5,
			"speed": 4000
		    }
		}
	    }
	}
    ]
}
EOF
    ) | curl -X PUT --data @- -H 'content-type: application/json' --data @- ${occi_srv}${id}
done
