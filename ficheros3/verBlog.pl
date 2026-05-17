#!/usr/bin/perl

use strict;
use warnings;
use CGI qw(:standard escapeHTML);

my $cgi = CGI->new;

print $cgi->header(-type => 'text/html', -charset => 'UTF-8');

my $login = $cgi->param('login') || '';
$login =~ s/^\s+|\s+$//g;

unless ($login =~ /^[a-zA-Z0-9._-]+$/) {
    print "<h2>Usuario inválido</h2>";
    exit;
}

my $blog_dir = "/home/$login/public_html/blog/posts";

unless (-d $blog_dir) {
    print qq{<!DOCTYPE html><html><body><h2>Blog no encontrado</h2></body></html>};
    exit;
}

opendir(my $dh, $blog_dir) or die "No se pudo abrir blog";
my @posts = sort { $b cmp $a } grep { /^post_\d+\.txt$/ } readdir($dh);
closedir($dh);

my $posts_html = '';
my $num_posts  = scalar(@posts);

foreach my $file (@posts) {
    my $ruta = "$blog_dir/$file";
    open(my $fh, '<:encoding(UTF-8)', $ruta) or next;
    my $contenido = do { local $/; <$fh> };
    close($fh);

    my ($autor, $fecha, $titulo, $texto) = split(/\n/, $contenido, 4);
    $autor  = escapeHTML($autor  || 'Anónimo');
    $fecha  = escapeHTML($fecha  || '');
    $titulo = escapeHTML($titulo || 'Sin título');
    $texto  = escapeHTML($texto  || '');
    $texto  =~ s/\n/<br>/g;

    my $inicial = uc(substr($autor, 0, 1));

    $posts_html .= qq{
    <div class="post-card">
        <div class="post-header">
            <div class="post-avatar">$inicial</div>
            <div class="post-meta">
                <div class="post-title">$titulo</div>
                <div class="post-info">
                    <i class="fas fa-user"></i> $autor
                    &nbsp;&middot;&nbsp;
                    <i class="fas fa-calendar-alt"></i> $fecha
                </div>
            </div>
        </div>
        <div class="post-body">$texto</div>
        <div class="post-actions">
            <a class="btn-action btn-edit" href="/cgi-bin/editarPost.pl?login=$login&post=$file">
                <i class="fas fa-edit"></i> Editar
            </a>
            <a class="btn-action btn-delete" href="/cgi-bin/borrarPost.pl?login=$login&post=$file"
               onclick="return confirm('¿Eliminar este post?');">
                <i class="fas fa-trash"></i> Borrar
            </a>
        </div>
    </div>
    };
}

unless ($posts_html) {
    $posts_html = qq{
    <div class="empty-state">
        <i class="fas fa-pen-nib"></i>
        <p>Todavía no hay publicaciones.</p>
        <p>¡Sé el primero en compartir una propuesta!</p>
    </div>
    };
}

print qq{
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Blog de $login — EcoSalmantica</title>
    <link href="https://fonts.googleapis.com/css2?family=Rajdhani:wght@400;600;700&family=Nunito:wght@400;600;700&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <style>
        :root {
            --green-main: #00c86e;
            --green-dark: #00a558;
            --green-light: #e6fff4;
            --dark:  #0d1f14;
            --dark-2: #163322;
            --card-bg: #1c2b36;
            --post-bg: #243544;
            --text-muted: rgba(255,255,255,0.55);
            --border: rgba(255,255,255,0.08);
        }
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            font-family: 'Nunito', sans-serif;
            background: linear-gradient(135deg, rgba(13,31,20,0.97) 0%, rgba(0,168,88,0.85) 100%),
                        url('https://marketplace.canva.com/e8sW8/MAFdpKe8sW8/1/tl/canva-vintage-dark-academia-aesthetic-styled-desk%2C-writer-aesthetic-MAFdpKe8sW8.jpg') center/cover no-repeat fixed;
            min-height: 100vh;
            color: white;
            padding: 0 0 60px;
        }

        /* NAV */
        .topbar {
            background: rgba(13,31,20,0.85);
            backdrop-filter: blur(12px);
            border-bottom: 1px solid var(--border);
            padding: 14px 30px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            flex-wrap: wrap;
            gap: 12px;
        }
        .topbar-brand {
            display: flex; align-items: center; gap: 10px;
            text-decoration: none;
        }
        .brand-icon {
            width: 38px; height: 38px; background: var(--green-main);
            border-radius: 9px; display: flex; align-items: center;
            justify-content: center; font-size: 17px; color: white;
        }
        .brand-text {
            font-family: 'Rajdhani', sans-serif; font-weight: 700;
            font-size: 17px; color: white; letter-spacing: 1px;
        }
        .brand-text span { color: var(--green-main); }
        .topbar-actions { display: flex; gap: 10px; flex-wrap: wrap; }
        .btn-top {
            display: inline-flex; align-items: center; gap: 7px;
            padding: 9px 18px; border-radius: 8px; font-weight: 700;
            font-size: 13px; text-transform: uppercase; letter-spacing: 0.5px;
            text-decoration: none; transition: all 0.2s; font-family: 'Rajdhani', sans-serif;
        }
        .btn-green  { background: var(--green-main); color: white; }
        .btn-green:hover { background: var(--green-dark); color: white; }
        .btn-outline { border: 1.5px solid rgba(255,255,255,0.3); color: white; }
        .btn-outline:hover { background: rgba(255,255,255,0.08); color: white; }

        /* HERO */
        .blog-hero {
            text-align: center;
            padding: 50px 20px 30px;
        }
        .blog-hero .badge {
            display: inline-flex; align-items: center; gap: 6px;
            background: rgba(0,200,110,0.14); border: 1px solid rgba(0,200,110,0.35);
            border-radius: 20px; padding: 4px 14px;
            font-size: 11px; color: var(--green-main); font-weight: 700;
            text-transform: uppercase; letter-spacing: 1px; margin-bottom: 14px;
        }
        .blog-hero h1 {
            font-family: 'Rajdhani', sans-serif;
            font-size: clamp(2rem, 5vw, 3.5rem);
            font-weight: 700; letter-spacing: 2px; margin-bottom: 8px;
        }
        .blog-hero h1 span { color: var(--green-main); }
        .blog-hero p { color: var(--text-muted); font-size: 15px; }
        .stats-bar {
            display: inline-flex; align-items: center; gap: 6px;
            background: rgba(255,255,255,0.07); border: 1px solid var(--border);
            border-radius: 10px; padding: 7px 18px;
            font-size: 13px; color: rgba(255,255,255,0.7);
            margin-top: 14px;
        }
        .stats-bar i { color: var(--green-main); }

        /* POSTS */
        .container {
            max-width: 820px;
            margin: 0 auto;
            padding: 0 20px;
        }
        .post-card {
            background: rgba(28,43,54,0.92);
            border: 1px solid var(--border);
            border-radius: 16px;
            padding: 28px;
            margin-bottom: 22px;
            transition: transform 0.2s, box-shadow 0.2s;
            position: relative;
            overflow: hidden;
        }
        .post-card::before {
            content: "";
            position: absolute; top: 0; left: 0; right: 0; height: 3px;
            background: var(--green-main);
            transform: scaleX(0); transform-origin: left;
            transition: transform 0.3s;
        }
        .post-card:hover { transform: translateY(-3px); box-shadow: 0 12px 36px rgba(0,0,0,0.3); }
        .post-card:hover::before { transform: scaleX(1); }

        .post-header {
            display: flex; align-items: flex-start; gap: 14px;
            margin-bottom: 18px;
        }
        .post-avatar {
            width: 46px; height: 46px; border-radius: 50%;
            background: var(--green-main);
            display: flex; align-items: center; justify-content: center;
            font-family: 'Rajdhani', sans-serif; font-weight: 700;
            font-size: 20px; color: white; flex-shrink: 0;
        }
        .post-meta { flex: 1; }
        .post-title {
            font-family: 'Rajdhani', sans-serif;
            font-size: 20px; font-weight: 700; margin-bottom: 5px;
            line-height: 1.3;
        }
        .post-info {
            font-size: 12px; color: var(--text-muted);
        }
        .post-info i { color: var(--green-main); }

        .post-body {
            font-size: 14px; line-height: 1.8;
            color: rgba(255,255,255,0.78);
            border-top: 1px solid var(--border);
            padding-top: 16px; margin-bottom: 18px;
        }

        .post-actions { display: flex; gap: 10px; flex-wrap: wrap; }
        .btn-action {
            display: inline-flex; align-items: center; gap: 6px;
            padding: 8px 16px; border-radius: 8px;
            font-size: 12px; font-weight: 700;
            text-transform: uppercase; letter-spacing: 0.5px;
            text-decoration: none; transition: all 0.2s;
            font-family: 'Rajdhani', sans-serif;
        }
        .btn-edit   { background: rgba(52,152,219,0.2); color: #4eb5f1; border: 1px solid rgba(52,152,219,0.3); }
        .btn-edit:hover { background: rgba(52,152,219,0.35); color: #4eb5f1; }
        .btn-delete { background: rgba(231,76,60,0.2); color: #e74c3c; border: 1px solid rgba(231,76,60,0.3); }
        .btn-delete:hover { background: rgba(231,76,60,0.35); color: #e74c3c; }

        .empty-state {
            text-align: center; padding: 60px 20px;
            color: var(--text-muted);
        }
        .empty-state i { font-size: 48px; color: var(--green-main); opacity: 0.4; display: block; margin-bottom: 16px; }
        .empty-state p { font-size: 15px; margin-bottom: 6px; }
    </style>
</head>
<body>

    <div class="topbar">
        <a class="topbar-brand" href="/~$login/">
            <div class="brand-icon"><i class="fas fa-leaf"></i></div>
            <div class="brand-text"><span>Eco</span>Salmantica</div>
        </a>
        <div class="topbar-actions">
            <a class="btn-top btn-green" href="/cgi-bin/nuevoPost.pl?login=$login">
                <i class="fas fa-plus"></i> Nuevo post
            </a>
            <a class="btn-top btn-outline" href="/~$login/">
                <i class="fas fa-arrow-left"></i> Volver al perfil
            </a>
        </div>
    </div>

    <div class="blog-hero">
        <div class="badge"><i class="fas fa-rss"></i> Blog Ciudadano</div>
        <h1>Blog de <span>$login</span></h1>
        <p>Propuestas y participación ciudadana en EcoSalmantica</p>
        <div class="stats-bar">
            <i class="fas fa-file-alt"></i>
            $num_posts publicacion(es)
        </div>
    </div>

    <div class="container">
        $posts_html
    </div>

</body>
</html>
};
