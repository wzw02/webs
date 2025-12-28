Структура проекта

├── .github\
├	├── workflows\
├	 ├	├── ci.yml
├── deploy-\
├	├── .env.template
├	├── docker-compose.yml
├	├── nginx-\
├	├──cond.d-\
|   |   |   ├── default.conf
|   ├── scripts-\
│   |   ├──deploy.sh
│   |   ├──health_check.sh
│   |   ├──rollback.sh
│   |   ├──setup.sh
│   |   ├──switch_traffic.sh
├── tests-\
│   ├── func-\
│   |   ├──run_curl_tests.sh
│   ├── unit-\
│   |   ├──tests_app.py
├── app.py
├── Dockerfile 
├── README.md 
├── requirements.txt
├── functionsal-test-report.txt
