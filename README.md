## Код на D, облегчающий жизнь

на данный момент требует компиляции вместе с проектом всех файлов
(потом вынесу в стат. библиотеку)

### математика
1. вектора
2. матрицы
3. построение матриц перехода
4. доп. функции (построение перспективы, LookAt матрицы и т.д. )

### графика

В основе лежит OpenGL, окно создаётся посредством SDL.
Необходим Derelict2

### утилиты
1. централизованная система логирования
2. реализация системы сигналов и слотов

### gui

Базируется на элементах из пакета графики,
использует систему сигналов и слотов
