module dport.gui.layout;

import dport.gui.element;

import dport.utils.system;
mixin( defaultModuleLogUtils("LayoutException") );

// TODO: написать больше расскладок

class LineWLayout: Layout
{
    override void opCall( irect bbox, Element[] chlist )
    {
        if( chlist.length == 0 ) return;
        float sh = bbox.h;
        auto dh = sh / cast(float)chlist.length;
        auto bufh = 0;
        foreach( i, ch; chlist )
        {
            ch.reshape( irect( 0, cast(int)bufh, bbox.w, cast(int)dh ) );
            bufh += dh;
        }
    }
}
