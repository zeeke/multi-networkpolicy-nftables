#!/usr/bin/env bats

# Reproducer for: "Ingress ALLOW traffic to a pod from using an OR combination
# of namespace and pod labels"
#
# Test Setup:
# - 3 namespaces: nsX (ns=x), nsY (ns=y), nsZ (ns=z)
# - Each namespace has 3 pods: pod-a (pod=a), pod-b (pod=b), pod-c (pod=c)
# - Policy on nsX/pod-a allows ingress from:
#     namespaceSelector: ns=y  OR  podSelector: pod=b
#
# Expected (podSelector without namespaceSelector matches policy namespace only):
# - All nsY pods can reach nsX/pod-a (namespace match)
# - nsX/pod-b can reach nsX/pod-a (pod label match, same namespace as policy)
# - nsX/pod-c, nsZ/pod-a, nsZ/pod-b, nsZ/pod-c are blocked

setup() {
	cd $BATS_TEST_DIRNAME
	load "common"

	server_net1=$(get_net1_ip "test-ns-or-pod-x" "pod-a")
}

@test "setup ns-or-pod-selector test environments" {
	kubectl create -f ns-or-pod-selector.yml

	run kubectl -n test-ns-or-pod-x wait --for=condition=ready -l app=test-ns-or-pod pod --timeout=${kubewait_timeout}
	[ "$status" -eq  "0" ]

	run kubectl -n test-ns-or-pod-y wait --for=condition=ready -l app=test-ns-or-pod pod --timeout=${kubewait_timeout}
	[ "$status" -eq  "0" ]

	run kubectl -n test-ns-or-pod-z wait --for=condition=ready -l app=test-ns-or-pod pod --timeout=${kubewait_timeout}
	[ "$status" -eq  "0" ]

	sleep 10
}

@test "check generated nftables rules" {
	sleep 10

	# Only nsX/pod-a should have nftables rules (policy target)
	run has_nftables_table "test-ns-or-pod-x" "pod-a"
	[ "$status" -eq  "0" ]

	run has_nftables_table "test-ns-or-pod-x" "pod-b"
	[ "$status" -eq  "1" ]

	run has_nftables_table "test-ns-or-pod-x" "pod-c"
	[ "$status" -eq  "1" ]
}

# nsX/pod-b -> nsX/pod-a: ALLOWED (podSelector: pod=b matches)
@test "ns-or-pod check nsX/pod-b -> nsX/pod-a (same ns, matching pod label)" {
	run kubectl -n test-ns-or-pod-x exec pod-b -- sh -c "echo x | nc -w 1 ${server_net1} 5555"
	[ "$status" -eq  "0" ]
}

# nsX/pod-c -> nsX/pod-a: BLOCKED (no match)
@test "ns-or-pod check nsX/pod-c -> nsX/pod-a (same ns, no matching label)" {
	run kubectl -n test-ns-or-pod-x exec pod-c -- sh -c "echo x | nc -w 1 ${server_net1} 5555"
	[ "$status" -eq  "1" ]
}

# nsY/pod-a -> nsX/pod-a: ALLOWED (namespaceSelector: ns=y matches)
@test "ns-or-pod check nsY/pod-a -> nsX/pod-a (matching namespace)" {
	run kubectl -n test-ns-or-pod-y exec pod-a -- sh -c "echo x | nc -w 1 ${server_net1} 5555"
	[ "$status" -eq  "0" ]
}

# nsY/pod-b -> nsX/pod-a: ALLOWED (both namespace and pod label match)
@test "ns-or-pod check nsY/pod-b -> nsX/pod-a (matching namespace and pod label)" {
	run kubectl -n test-ns-or-pod-y exec pod-b -- sh -c "echo x | nc -w 1 ${server_net1} 5555"
	[ "$status" -eq  "0" ]
}

# nsY/pod-c -> nsX/pod-a: ALLOWED (namespaceSelector: ns=y matches)
@test "ns-or-pod check nsY/pod-c -> nsX/pod-a (matching namespace)" {
	run kubectl -n test-ns-or-pod-y exec pod-c -- sh -c "echo x | nc -w 1 ${server_net1} 5555"
	[ "$status" -eq  "0" ]
}

# nsZ/pod-a -> nsX/pod-a: BLOCKED (no match)
@test "ns-or-pod check nsZ/pod-a -> nsX/pod-a (no match)" {
	run kubectl -n test-ns-or-pod-z exec pod-a -- sh -c "echo x | nc -w 1 ${server_net1} 5555"
	[ "$status" -eq  "1" ]
}

# nsZ/pod-b -> nsX/pod-a: BLOCKED (podSelector without namespaceSelector only matches policy namespace)
@test "ns-or-pod check nsZ/pod-b -> nsX/pod-a (pod label match but wrong ns)" {
	run kubectl -n test-ns-or-pod-z exec pod-b -- sh -c "echo x | nc -w 1 ${server_net1} 5555"
	[ "$status" -eq  "1" ]
}

# nsZ/pod-c -> nsX/pod-a: BLOCKED (no match)
@test "ns-or-pod check nsZ/pod-c -> nsX/pod-a (no match)" {
	run kubectl -n test-ns-or-pod-z exec pod-c -- sh -c "echo x | nc -w 1 ${server_net1} 5555"
	[ "$status" -eq  "1" ]
}

@test "cleanup environments" {
	kubectl delete -f ns-or-pod-selector.yml
	run kubectl -n test-ns-or-pod-x wait --for=delete -l app=test-ns-or-pod pod --timeout=${kubewait_timeout}
	[ "$status" -eq  "0" ]
	run kubectl -n test-ns-or-pod-y wait --for=delete -l app=test-ns-or-pod pod --timeout=${kubewait_timeout}
	[ "$status" -eq  "0" ]
	run kubectl -n test-ns-or-pod-z wait --for=delete -l app=test-ns-or-pod pod --timeout=${kubewait_timeout}
	[ "$status" -eq  "0" ]
}
