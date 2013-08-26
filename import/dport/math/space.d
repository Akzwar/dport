/++
 вычисление полной матрицы трансформации для отрисовки
 +/
module dport.math.space;

import dport.math.types;

/++
 интерфейс узла

 Реализация должна содержать матрицу, 
 описывающую трансформацию относительно родителя
 и как таковую ссылку на родителя.

 Если ссылка на родителя является null,
 то считается что объект содержит матрицу в глобальных 
 координатах
 +/
interface Node
{
    /++ матрица трансформации из локальной СК в глобальную (родительские) СК +/
    @property mat4 self() const;
    /++ ссылка на родителя +/
    @property Node parent();
}

/++
 Вычислитель полной матрицы трансформации между объектами 
 TODO: написать кэширование результатов
 +/
class Resolver
{
    /++ 
        Params:
        obj = объект, который рендерится
        cam = объект, взятый за камеру
        Returns: такая матрица что (X_1)_2 = A^2_1 * X_1, где A^2_1 матрица перехода
     +/
    mat4 opCall( Node obj, Node cam )
    {
        Node[] obj_branch, cam_branch;
        obj_branch ~= obj;
        cam_branch ~= cam;

        while( obj_branch[$-1] !is null )
            obj_branch ~= obj_branch[$-1].parent;
        while( cam_branch[$-1] !is null )
            cam_branch ~= cam_branch[$-1].parent;

        top: 
        foreach( cbi, camparents; cam_branch )
            foreach( obi, objparents; obj_branch )
                if( camparents == objparents )
                {
                    cam_branch = cam_branch[0 .. cbi+1];
                    obj_branch = obj_branch[0 .. obi+1];
                    break top;
                }

        mat4 obj_mtr, cam_mtr;

        foreach( node; obj_branch )
            if( node ) obj_mtr = node.self * obj_mtr;
            else break;

        foreach( node; cam_branch )
            if( node ) cam_mtr = cam_mtr * node.self.speed_transform_inv;
            else break;

        return cam_mtr * obj_mtr;
    }

    /++ переопределять для кэширования матриц +/
    //mat4 opCall( const Node obj, const Node cam ) { return opCall( obj, cam ); }
}
