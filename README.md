## Kubernetes Certifications (CKA/CKAD)

Practice materials and notes for Kubernetes certifications. Includes hands-on labs, a simple Terraform setup to provision practice droplets, and a kubeadm cluster setup guide.

### Repository contents
- `CKA-hands-on-labs.md`: tasks and notes for CKA practice
- `CKAD-hands-on-labs.md`: tasks and notes for CKAD practice
- `manual-cluster/`: Terraform to create 3 Ubuntu 22.04 droplets in `sgp1` (DigitalOcean)
- `kubeadm-cluster-setup.md`: step-by-step kubeadm setup on Ubuntu 22.04

### Quickstart
- Create practice nodes on DigitalOcean (3 droplets):
  ```bash
  export DIGITALOCEAN_TOKEN=your_token_here
  cd manual-cluster
  terraform init
  terraform apply
  ```
- Set up a small cluster with kubeadm:
  ```bash
  # Follow the guide
  open kubeadm-cluster-setup.md
  ```

### Exam structure (Linux Foundation)
High-level details for LF Kubernetes exams (CKA/CKAD/CKS):
- Performance-based, hands-on tasks executed in a live Kubernetes environment
- Remote, proctored, browser-based exam environment
- Time-limited with a published passing score; always check the official page for current duration, domains, and policies
- Access to official Kubernetes documentation during the exam (permitted domains are defined by LF exam policy)
- Tasks cover real-world objectives aligned to the respective exam blueprint

Refer to the Linux Foundation Training & Certification site for authoritative, up-to-date exam structure, policies, and blueprints: [Linux Foundation Training & Certification](https://training.linuxfoundation.org).

Useful certification page:
- CKAD: https://training.linuxfoundation.org/certification/certified-kubernetes-application-developer-ckad/
- CKA: https://training.linuxfoundation.org/certification/certified-kubernetes-administrator-cka/


