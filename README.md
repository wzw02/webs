# **Project Structure**

├── **.github**/\
├	├── **workflows**/\
├	├	├── **ci-cd-pipeline.yml**\
├── **deploy**/\
├	├── **.env.template**\
├	├── **docker-compose.yml**\
├	├── **nginx**/\
├	├	├──**cond.d**/\
├	├	├── **default.conf**\
├	├── **scripts**/\
├	├	├──**deploy.sh**\
├	├	├──**health_check.sh**\
├	├	├──**rollback.sh**\
├	├	├──**setup.sh**\
├	├	├──**switch_traffic.sh**\
├── **tests**/\
├	├── **func**/\
├	├	├──**run_curl_tests.sh**\
├	├── **unit**/\
├	├	├──**tests_app.py**\
├── **app.py**\
├── **Dockerfile** \
├── **README.md** \
├── **requirements.txt**\
├── **functionsal-test-report.txt**\



## CI/CD pipeline

### 1. **Automated test pipeline**

- **Unit test**：Use pytest for code-level testing and generate coverage reports.
- **Functional test**：Launch the application and test the main API endpoints (health check, addition, multiplication, error handling).

### 2. **Image building and management**

- **GHCR integration**：Push to GitHub Container Registry
- **Local verification**：First build a local image, then push it to the remote repository.

### 3. **Blue-green deployment strategy**

- **Two-color deployment**：Use two environments: blue and green.
- **Zero downtime switchover**：The new version starts in the background and updates the routing after the health check is passed.
- **Quick rollback**：Quickly revert to the previous version by switching colors.

