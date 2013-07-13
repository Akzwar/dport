module dport.isys.neiro.art;

import dport.utils.information,
       dport.utils.system,
       dport.math.types,
       std.math;

mixin( defaultModuleLogUtils( "ARTDetectorException" ) );

class ART( size_t DIM ) 
{
    alias tensor!(DIM,float) MapType;
    alias Information!size_t RetType;

    float threshold;

    struct Image
    {
        size_t cnt = 0;
        MapType img;

        this( size_t[DIM] imsize )
        {
            img = MapType( imsize );
            img.data[] = 0;
        }

        this( in MapType init )
        {
            img = init;
            cnt = 1;
        }

        float diff( in MapType dimg )
        {
            float d = 0;
            foreach( i; 0 .. img.data.length )
                d += abs( img.data[i] - dimg.data[i] );
            d /= img.data.length;
            return d;
        }

        void add( in MapType newimg )
        {
            if( img.data.length != newimg.data.length )
                throw new ARTDetectorException( "bad in img size" );

            auto newcnt = cnt + 1;
            foreach( i; 0 .. img.data.length )
                img.data[i] = ( img.data[i] * cnt + newimg.data[i] ) / newcnt;
            cnt = newcnt;
        }
    }

    Image[] images;

    RetType opCall( in MapType img )
    {
        float min_diff = float.max;
        size_t img_no = 0;

        foreach( i, saved; images )
        {
            auto cdiff = saved.diff( img );
            if( cdiff < min_diff )
            {
                min_diff = cdiff;
                img_no = i;
            }
        }

        RetType rt;
        rt.topicality = 1;

        if( min_diff <= threshold )
        {
            images[img_no].add( img );
            rt.val = img_no;
            rt.completeness = 1.0 - min_diff;
        }
        else
        {
            images ~= Image( img );
            rt.val = images.length-1;
            rt.completeness = 1;
        }

        return rt;
    }
}
