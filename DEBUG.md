# Debug — curl to EC2 public IP hangs

## Scenario

Pipeline passes. SSH into the instance, `curl localhost:4444` gives back the
expected JSON. From my laptop, `curl http://<public-ip>:4444` just hangs
until I hit Ctrl-C. No "connection refused", no timeout message, just silence.

The key detail is that it hangs instead of being refused. A hang means my
SYN packet is being silently dropped somewhere — nobody is answering. If the
port was simply closed or the app wasn't listening, I'd get "connection refused"
right away because the kernel would send back a RST.

## Hypotheses

1. **Security Group is missing an allow rule for port 4444.**
   AWS Security Groups drop traffic that isn't explicitly allowed, with no
   response at all — which matches the silent hang I'm seeing.

2. **A Network ACL on the subnet or a host-level firewall (ufw/iptables) is
   blocking port 4444.**
   NACLs are stateless and drop by default too, producing the same hang
   symptom; a host firewall like ufw could also silently discard the packet
   before it reaches the app.

## Verification

1. Go to EC2 in the AWS console, click on the instance, open the Security
   Group, and look at the Inbound rules tab. If there's no rule for
   TCP 4444, that's the problem. Can also check from the terminal:
   ```
   aws ec2 describe-security-groups --group-ids <sg-id> --query "SecurityGroups[*].IpPermissions"
   ```
   And from my laptop I can test with:
   ```
   nc -vz <public-ip> 4444
   ```
   If it just hangs (instead of saying "refused"), that confirms something
   is dropping the packet before it reaches the app.

2. Check the subnet's NACL in VPC > Subnets > select subnet > Network ACL,
   and look at both inbound and outbound rules. On the instance itself, run:
   ```
   sudo ufw status
   sudo iptables -L -n
   ```
   If any of these show a deny or missing allow for 4444, that's the cause.

## Fix

Add the missing inbound rule to the Security Group:

```
aws ec2 authorize-security-group-ingress \
  --group-id <sg-id> \
  --protocol tcp \
  --port 4444 \
  --cidr 0.0.0.0/0
```

If it turned out to be a NACL or host firewall instead, just open port 4444
there. No need to rebuild the VPC or change Terraform.

## Lesson

When a packet is **dropped** (by a Security Group or NACL), there's no reply
at all — the client just waits and retransmits, which looks like a hang. When
a packet **reaches a closed port**, the host sends back a TCP RST and the
client immediately gets "connection refused". The symptom tells you whether
the problem is a firewall silently eating packets or the app genuinely not
listening.
