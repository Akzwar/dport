/++
 отрисовка списка элементов View
 +/
module dport.gui.list;

import dport.gui.base;

/++
 класс-контейнер для содержания списка View
 и управления передачей событий им
 +/
class ViewList: View
{
private:
    void idle_hook( real dtime )
    {
        foreach( v; list )
            v.idle( dtime );
    }

    void activate_hook() { if( cur ) cur.activate(); }
    void release_hook() { if( cur ) cur.release(); }

protected:
    View cur;

    /++ функция должна быть переопределена, 
        чтобы выставлять размеры дочерних элеметов
     +/
    void reshape_hook( in irect ) {}

    /++ поиск элемента под курсором +/
    bool findCurrent( in ivec2 mpos )
    {
        foreach_reverse( v; list )
        {
            if( mpos in v.rect )
            {
                if( cur && cur != v )
                    cur.release();
                cur = v;
                cur.activate();
                return true;
            }
        }
        if( cur ) cur.release();
        cur = null;
        return false;
    }

    void draw_hook()
    {
        foreach_reverse( v; list )
            v.draw();
    }

public:
    this()
    {
        keyboard.addCondition( ( mpos, key ){ return findCurrent( mpos ); } );
        keyboard.connect( &(cur.keyboard.opCall) );

        mouse.addCondition( ( mpos, me ){ return findCurrent( mpos ); } );
        mouse.connect( &(cur.mouse.opCall) );

        idle.connect( &idle_hook );
        reshape.connect( &reshape_hook );

        activate.connect( &activate_hook );
        release.connect( &release_hook );

        //draw.connect( 
        //        (){ foreach_reverse( v; list ) v.draw(); }, 
        //        hook_name );
        draw.connect( &draw_hook );
    }

    View[] list;
}
