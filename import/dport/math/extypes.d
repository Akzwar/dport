/++ 
 различные функции для работы с типами данных, не входящие в категорию чисто математических
 TODO: перевести часть функций из @property в обычные
 +/
module dport.math.extypes;

import std.math;

public import dport.math.types;

/++ добавить смещение к матрице трансформации
    Params:
    mtr = ссылка на матрицу
    mv = вектор смещения
 +/
@property void move(string S,T)( ref mat4 mtr, in vec!(S,T) mv )
{
    mtr[0,3] += mv[0];
    mtr[1,3] += mv[1];
    mtr[2,3] += mv[2];
}

/++ выставить смещение у матрицы трансформации
    Params:
    mtr = ссылка на матрицу
    mv = вектор смещения
 +/
@property void setpos(string S,T)( ref mat4 mtr, in vec!(S,T) mv )
{
    mtr[0,3] = mv[0];
    mtr[1,3] = mv[1];
    mtr[2,3] = mv[2];
}

/++ построение матрицы поворота
    как у Жукова
    TODO: аналитически умножить матрицы
    Params:
    mtr = ссылка на матрицу
    ry = рыскание 
    rz = тангаж 
    rx = крен 
    Returns: матрица 4x4
+/
mat4 rotA( float ry, float rz, float rx )
{
    return   mat4([       1,        0,        0, 0,
                          0,  cos(rx), -sin(rx), 0,
                          0,  sin(rx),  cos(rx), 0,
                          0,        0,        0, 1 ]) *
             mat4([ cos(rz), -sin(rz),        0, 0,
                    sin(rz),  cos(rz),        0, 0,
                          0,        0,        1, 0,
                          0,        0,        0, 1 ]) *
             mat4([ cos(ry),        0,  sin(ry), 0,
                          0,        1,        0, 0,
                   -sin(ry),        0,  cos(ry), 0,
                          0,        0,        0, 1 ]);
}

/++ построение матрицы трансформации
    Params:
    cpos = откуда смотрим
    target = куда смотрим
    up = направление вверх
    Returns: матрица трансформации
 +/
mat4 lookAt( in vec3 cpos, in vec3 target, in vec3 up )
{
    auto z = -(target - cpos).e;
    auto x = (up * z).e;
    vec3 y;
    if( x )
        y = (z * x).e;
    else
    {
        y = (vec3(1,0,0) * z).e;
        x = (y * z).e;
    }
    return mat4([ x.x, y.x, z.x, cpos.x,
                  x.y, y.y, z.y, cpos.y,
                  x.z, y.z, z.z, cpos.z,
                    0,   0,   0,       1 ]);
}

/++ построение матрицы перспективной трансформации
    Params:
    fov = угол обзора по ширине (кажется, может и по высоте)
    aspect = отношение ширины к высоте
    znear = ближайшая плоскость отсечения
    zfar = дальняя плоскость отсечения
    Returns: матрица трансформации
 +/
mat4 perspective(float fov, float aspect, float znear, float zfar)
{
    float xymax = znear * tan(fov * PI / 360.0);
    float ymin = -xymax;
    float xmin = -xymax;

    float width = xymax - xmin;
    float height = xymax - ymin;

    float depth = znear - zfar;
    float q = (zfar + znear) / depth;
    float dzn = 2.0 * znear;
    float qn = dzn * zfar / depth;

    float w = dzn / ( width * aspect );
    float h = dzn / height;

    return mat4([ w, 0,  0, 0,
                  0, h,  0, 0,
                  0, 0,  q, qn,
                  0, 0, -1, 0 ]);
}
