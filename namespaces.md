There are two test failures

https://jenkins-csb-telco-ci-cd-auto.dno.corp.redhat.com/view/Network/job/e2e-network/167/testReport/junit/(root)/CNF%20Features%20e2e%20integration%20tests/_It___multinetworkpolicy__MultiNetworkPolicy_SR_IOV_integration_Ingress_ALLOW_traffic_to_a_pod_from_using_an_OR_combination_of_namespace_and_pod_labels/

https://jenkins-csb-telco-ci-cd-auto.dno.corp.redhat.com/view/Network/job/e2e-network/167/testReport/junit/(root)/CNF%20Features%20e2e%20integration%20tests/_It___multinetworkpolicy__MultiNetworkPolicy_SR_IOV_integration_Stacked_policies_enforce_multiple_Ingress_stacked_policies_with_overlapping_podSelector_and_different_ports/

whose code is defined here
https://github.com/openshift-kni/cnf-features-deploy/blob/master/cnf-tests/testsuites/e2esuite/multinetworkpolicy/multinetworkpolicy_sriov.go

I want to create a reproducer for that problem as a bats test under `e2e/tests`.

Spin up the kind cluster following the instructions and try to run the test.
