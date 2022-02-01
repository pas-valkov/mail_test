# mail_test
Тестовое задание на стажировку от Mail
---------------------------------------------------------------
Задание:
Реализовать kv-хранилище доступное по http с помощью tarantool
API:
- POST /kv body: {key: "test", "value": {SOME ARBITRARY JSON}} 
- PUT kv/{id} body: {"value": {SOME ARBITRARY JSON}}
- GET kv/{id} 
- DELETE kv/{id}

- POST  возвращает 409 если ключ уже существует, 
- POST, PUT возвращают 400 если боди некорректное
- PUT, GET, DELETE возвращает 404 если такого ключа нет
- все операции логируются
- в случае, если число запросов в секунду в http api превышает заданый интервал, возвращать 429 ошибку.
---------------------------------------------------------------
Приложение развёрнуто на 3.142.239.46 с параметрами, указанными в config.lua

Пример использования для текущих параметров:

curl -XPOST http://3.142.239.46:8080/mail_test/ -d '{"key":"q1", "value": "value"}'

curl -XGET http://3.142.239.46:8080/mail_test/q1

curl -XPUT http://3.142.239.46:8080/mail_test/q1 -d '{"value": "new_value"}'

curl -XDELETE http://3.142.239.46:8080/mail_test/q1