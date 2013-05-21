module dport.utils.logsys;

import std.stdio, 
       std.conv,
       std.typecons;

enum logType { FATAL=0, ERROR=1, WARN=2, UTEST=3, INFO=4, DEBUG=5, EXCEPT=6, TRACE=7 };

class LogException: Exception { this( string msg ){ super( msg ); } }

class SystemInfo
{
    import std.getopt,
           std.file,
           std.path,
           std.string;

    string path;

    this( string[] args )
    {
        path = buildNormalizedPath( dirName( absolutePath( args[0] ) ), ".." );
    }

    string getPath( string file )
    {
        return buildNormalizedPath( path, file );
    }
}

SystemInfo sysinfo;

private
{
    struct LogCommand
    {
        logType type;
        string name;
        string msg;
    }

    struct ManCommand
    {
        string name;
        logType level;
    }

    import std.string, std.getopt;
    class LogSystem
    {
        File ff;

        class LogGraph
        {
            this( logType ll ){ level = ll; }
            LogGraph[string] children;
            logType level;

            bool check( logType lt, string[] name )
            {
                if( lt > level ) return 0;
                if( name.length && name[0] in children )
                    return children[name[0]].check( lt, name[1 .. $] );
                return 1;
            }

            bool set( logType lt, string[] name )
            {
                if( name[0] in children )
                    return children[name[0]].set( lt, name[1 .. $] );
                else if( name.length > 1 )
                {
                    children[name[0]] = new LogGraph(level);
                    children[name[0]].set( lt, name[1 .. $] );
                    return 1;
                }
                else if( name.length == 1 )
                {
                    children[name[0]] = new LogGraph(lt);
                    return 1;
                }
                else 
                {
                    level = lt;
                    return 0;
                }
            }
        }

        LogGraph root;

        this() 
        { 
            ff = stderr; 
            root = new LogGraph( logType.TRACE );
        }

        void setup( string[] args )
        {
            string fname = "stderr";
            getopt( args,
                    "loglevel", &root.level,
                    "logfile", &fname );
            ff.writeln( "[LOGSYS] max log level: ", root.level );
            ff.writeln( "[LOGSYS] log output file: ", fname );

            if( fname == "stderr" )
                ff = stderr;
            else if( fname == "stdout" )
                ff = stdout;
            else
                ff = File( fname, "w" );

        }

        void log( LogCommand lcmd )
        {
            if( root.check( lcmd.type, lcmd.name.split(".") ) )
                ff.writefln( "[% 6s] [%s]: %s", lcmd.type, lcmd.name, lcmd.msg );
        }

        void manage( ManCommand mcmd )
        {
            if( root.set( mcmd.level, mcmd.name.split("." ) ) )
                ff.writeln( "[LOGSYS] register logger \"", mcmd.name, 
                        "\" with log level ", mcmd.level );
            else
                ff.writeln( "[LOGSYS] set new level for \"", mcmd.name, 
                        "\": ", mcmd.level );
        }

    }

    LogSystem ls;
}

static this() { ls = new LogSystem(); }

class DPortException: Exception 
{ 
    this( string name, string msg ) 
    { 
        super( "[" ~ name ~ "]: " ~ msg ); 
        fnsend( LogCommand( logType.EXCEPT, name, msg ) );
    } 
}

void setupLogging( string[] args ) 
{ 
    sysinfo = new SystemInfo( args );
    ls.setup( args );
}

private void fnsend(T)( T cmd )
{
    if( ls is null ) return;
    static if( is( T == LogCommand ) )      ls.log( cmd );
    else static if( is( T == ManCommand ) ) ls.manage( cmd );
}

class Logger
{
private:
    string name;
    logType maxLT;

public:
    this( string Name, logType lt=logType.TRACE )
    {
        name = Name;
        maxLT = lt;
        fnsend( ManCommand( name, lt ) );
    }

    final void log(T...)( logType lt, T args )
    {
        if( lt > maxLT ) return;
        string msg = "";
        foreach( arg; args )
            msg ~= to!string(arg);
        fnsend( LogCommand( lt, name, msg ) );
    }

    final void fatal(T...)( T args ) { log( logType.FATAL, args ); }
    final void error(T...)( T args ) { log( logType.ERROR, args ); }
    final void warn(T...)( T args )  { log( logType.WARN,  args ); }
    final void utest(T...)( T args ) { log( logType.UTEST, args ); }
    final void info(T...)( T args )  { log( logType.INFO,  args ); }
    final void Debug(T...)( T args ) { log( logType.DEBUG, args ); }
    final void trace(T...)( T args ) { log( logType.TRACE, args ); }

    final void start( string method ) { log( logType.DEBUG, method, " [start]" ); }
    final void success( string method ) { log( logType.INFO, method, " [success]" ); }
}

string defaultModuleLogUtils(string ExceptName)
{
    return r"
    private {
        import std.traits;
        debug {
            Logger logger;
            Logger log() 
            { 
                if( !logger ) 
                    logger = new Logger( moduleName!logger, logType.TRACE ); 
                return logger;
            }
        } 
    }

    class " ~ ExceptName ~ r": DPortException
    { this( string msg ){ super( moduleName!(typeof(this)), msg ); } }
    ";
}

//private
//{
//
//    void mainLoop()
//    {
//        //auto ls = new LogSystem;//( [""] );
//        
//        for( bool run = true; run; )
//        {
//            //receive( &(ls.log), &(ls.register));
//            receive(
//                    ( logType lt, string name, string msg ) { writefln( "okda" ); },
//                    ( string name, logType lt ) { writefln( "okda2" ); }
//                   );
//        }
//    }
//
//}
