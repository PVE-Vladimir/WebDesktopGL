#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <X11/Xutil.h>
#include <unistd.h>
#include <ctype.h>
#include <sys/wait.h>
#include <pthread.h>
// sudo apt install build-essential libx11-dev libxtst-dev
static Display *display;

// Prints help
void print_help(const char *program_name) {
    char *help_text[] = {
        "Usage: %s <-help> \n",
        "       %s <command> [options] [arguments]\n",
        "Commands:\n",
        "  -help, --help, --h, -h    Show this help message\n",
        "  windowmove <win_id> <X> <Y>\n",
        "                            Move window to (X, Y) coordinates\n",
        "                            Example: %s windowmove 0x6000001 100 200\n",
        "  windowsize <win_id> <W> <H>\n",
        "                            Resize window to width W, height H\n",
        "                            Example: %s windowsize 0x6000001 800 600\n",
        "  getwindowgeometry <win_id>\n",
        "                            Get window position and size\n",
        "                            Example: %s getwindowgeometry 0x6000001\n",
        "  search (--name <title> | --pid <pid>)\n",
        "                            Find windows by title or process ID\n",
        "                            Example: %s search --name \"Terminal\"\n",
        "                            Example: %s search --pid 12345\n",
        "  xseticon <win_id> <icon_data...>\n",
        "                            Set window icon (ARGB format)\n",
        "                            Example: %s xseticon 0x6000001 2 2 0xffff0000 0x0000ffff 0xcccc0b09 0x10101010\n",
        "  xseticon_gif <window_id> <file> [<frame_rate 1-120> — optional, otherwise 20. 20 is recommended]\n",
        "                            Icon.txt (bash array:ARGB format) is created by the script make_window_icon_txt.sh\n",
        "                            Example: %s xseticon_gif 0x6000001 /home/sysadmin/Desktop/test/imege_6/imege_6.txt\n",
        "  _NET_WM <win_id> <action> [args]\n",
        "      Actions:\n",
        "        info [property]         - Get window info (title, position, size, etc.)\n",
        "                                  Properties: xwininfo, AbsoluteX, AbsoluteY, RelativeX,\n",
        "                                              RelativeY, Width, Height, Depth, Visual,\n",
        "                                              VisualClass, Border, Class, Colormap, Bit,\n",
        "                                              WindowGravity, Backing, Save, Map, Override,\n",
        "                                              Corners, geometry, _NET_WM_STATE\n",
        "                            Window manager operations:\n",
        "                              info                 - Show detailed window info\n",
        "                              info <property>      - Show specific property\n",
        "                              hide                 - Minimize window\n",
        "                              show                 - Restore window\n",
        "                              show_raised          - Show and focus window\n",
        "                              maximize             - Maximize window\n",
        "                              reduce               - remove high states or minimize window into window\n",
        "                              rename               - change the window name\n",
        "                              fullscreen           - Toggle fullscreen\n",
        "                              unfullscreen         - Exit fullscreen\n",
        "                              lower_window         - Lower window\n",
        "                              state_above[0/1]     - Set window always on top (0=remove, 1=add)\n",
        "                              state_below[0/1]     - Set window always below (0=remove, 1=add)\n",
        "                              state_shade[0/1]     - Shade/unshade window (0=unshade, 1=shade)\n",
        "                              decorated[0/1]       - Toggle window decorations (0=remove, 1=add): without frame \n",
        "                              close                - Close window\n",
        "                            Example: %s _NET_WM 0x6000001 info\n",
        "                            Example: %s _NET_WM 0x6000001 info Map\n",
        "                            Example: %s _NET_WM 0x6000001 state_above1\n",
        "                            Example: %s _NET_WM 0x6000001 rename \"New title test\"\n",
        "  _NET_WM_ICON <win_id>   Show window icon pixel data\n",
        "                          Example: %s _NET_WM_ICON 0x6000001\n"
    };

    size_t count = sizeof(help_text) / sizeof(help_text[0]);

    for (size_t i = 0; i < count; ++i) {
        if (strstr(help_text[i], "%s")) {
            printf(help_text[i], program_name);
        } else {
            printf("%s", help_text[i]);
        }
    }
}

// send ClientMessage to all windows
void send_msg(Window w,  Atom a, Atom b, Atom msg)
{
    XEvent e = { .xclient = {
        .type = ClientMessage,
        .send_event = True,
        .display = display,
        .window = w,
        .message_type = msg,
        .format = 32,

        .data.l = { a, b, 0, 0, 0 }
    }};
    XSendEvent(display, DefaultRootWindow(display), False,
              SubstructureRedirectMask|SubstructureNotifyMask, &e);

    XFlush(display);
}

// Sets|removes window decorations
void set_decorations(Window w, int on)
{
    Atom motif = XInternAtom(display, "_MOTIF_WM_HINTS", False);
    if (motif == None) return;

    struct {
        unsigned long flags, functions, decorations;
        long          input_mode;
        unsigned long status;
    } hints = { .flags = 2,
                .functions = 0,
                .decorations = on,
                .input_mode = 0,
                .status = 0 };

    XChangeProperty(display, w, motif, motif, 32,
                    PropModeReplace, (unsigned char *)&hints, 5);
    XFlush(display);
}

// Sets the window title
void set_title(Window w,  char *new_title)
{
    Atom utf8 = XInternAtom(display, "UTF8_STRING", False);

    /* old ICCCM standard */
    XStoreName(display, w, new_title);

    /* new EWMH standard */
    Atom net_wm_name = XInternAtom(display, "_NET_WM_NAME", False);
    XChangeProperty(display, w, net_wm_name, utf8, 8,
                    PropModeReplace,
                    (unsigned char *)new_title,
                    strlen(new_title));
    XFlush(display);
}

// Displays information about the window depending on the info parameter
void print_window_info(Window win, char *info)
{

    XWindowAttributes attr;
    XGetWindowAttributes(display, win, &attr);

    char *name = NULL;
    XFetchName(display, win, &name);

    Atom utf8         = XInternAtom(display, "UTF8_STRING", False);
    Atom net_wm_name  = XInternAtom(display, "_NET_WM_NAME", False);
    Atom net_wm_state = XInternAtom(display, "_NET_WM_STATE", False);
    Atom actual_type; int actual_fmt; unsigned long n, left; unsigned char *data = NULL;
    if (XGetWindowProperty(display, win, net_wm_name, 0, 1024, False, utf8,
        &actual_type, &actual_fmt, &n, &left, &data) == Success && data)
    { if (name) XFree(name); name = (char*)data; }

    int xabs, yabs; Window dummy;
    XTranslateCoordinates(display, win, DefaultRootWindow(display),
                          0, 0, &xabs, &yabs, &dummy);

    const char *class_str = (attr.class == InputOutput) ? "InputOutput" : "InputOnly";

    const char *visual_class_str;
    switch (attr.visual->class) {
    case StaticGray:  visual_class_str = "StaticGray";  break;
    case GrayScale:   visual_class_str = "GrayScale";   break;
    case StaticColor: visual_class_str = "StaticColor"; break;
    case PseudoColor: visual_class_str = "PseudoColor"; break;
    case TrueColor:   visual_class_str = "TrueColor";   break;
    case DirectColor: visual_class_str = "DirectColor"; break;
    default:          visual_class_str = "unknown";     break;
    }

    /* --------------  Gravity strings -------------- */
    const char *grav_str[] = {
        [ForgetGravity]    = "ForgetGravity",
        [NorthWestGravity] = "NorthWestGravity",
        [NorthGravity]     = "NorthGravity",
        [NorthEastGravity] = "NorthEastGravity",
        [WestGravity]      = "WestGravity",
        [CenterGravity]    = "CenterGravity",
        [EastGravity]      = "EastGravity",
        [SouthWestGravity] = "SouthWestGravity",
        [SouthGravity]     = "SouthGravity",
        [SouthEastGravity] = "SouthEastGravity",
        [StaticGravity]    = "StaticGravity"
    };
    const char *bit_grav  = grav_str[attr.bit_gravity];
    const char *win_grav  = grav_str[attr.win_gravity];

    int sw = DisplayWidth(display,  DefaultScreen(display));
    int sh = DisplayHeight(display, DefaultScreen(display));
    if (strcmp(info, "info") == 0) { printf("xwininfo: Window id: 0x%lx \"%s\"\n", win, name ? name : "(no title)");
    } else if (strcmp(info, "xwininfo") == 0) { printf("0x%lx \"%s\"\n", win, name ? name : "(no title)"); }
    if (strcmp(info, "info") == 0) { printf("  Absolute upper-left X:  %d\n", xabs);
    } else if (strcmp(info, "AbsoluteX") == 0) { printf("%d\n", xabs); }
    if (strcmp(info, "info") == 0) { printf("  Absolute upper-left Y:  %d\n", yabs);
    } else if (strcmp(info, "AbsoluteY") == 0) { printf("%d\n", yabs); }
    if (strcmp(info, "info") == 0) { printf("  Relative upper-left X:  %d\n", attr.x);
    } else if (strcmp(info, "RelativeX") == 0) { printf("%d\n", attr.x); }
    if (strcmp(info, "info") == 0) { printf("  Relative upper-left Y:  %d\n", attr.y);
    } else if (strcmp(info, "RelativeY") == 0) { printf("%d\n", attr.y); }
    if (strcmp(info, "info") == 0) { printf("  Width: %d\n", attr.width);
    } else if (strcmp(info, "Width") == 0) { printf("%d\n", attr.width); }
    if (strcmp(info, "info") == 0) { printf("  Height: %d\n", attr.height);
    } else if (strcmp(info, "Height") == 0) { printf("%d\n", attr.height); }
    if (strcmp(info, "info") == 0) { printf("  Depth: %d\n", attr.depth);
    } else if (strcmp(info, "Depth") == 0) { printf("%d\n", attr.depth); }
    if (strcmp(info, "info") == 0) { printf("  Visual: 0x%lx\n", (unsigned long)attr.visual->visualid);
    } else if (strcmp(info, "Visual") == 0) { printf("0x%lx\n", (unsigned long)attr.visual->visualid); }
    if (strcmp(info, "info") == 0) { printf("  Visual Class: %s\n", visual_class_str);
    } else if (strcmp(info, "VisualClass") == 0) { printf("%s\n", visual_class_str); }
    if (strcmp(info, "info") == 0) { printf("  Border width: %d\n", attr.border_width);
    } else if (strcmp(info, "Border") == 0) { printf("%d\n", attr.border_width); }
    if (strcmp(info, "info") == 0) { printf("  Class: %s\n", class_str);
    } else if (strcmp(info, "Class") == 0) { printf("%s\n", class_str); }
    if (strcmp(info, "info") == 0) {
        if (attr.colormap != None) { printf("  Colormap: 0x%lx (not installed)\n", (unsigned long)attr.colormap);
        } else { printf("  Colormap: 0x%lx (none)\n", (unsigned long)attr.colormap); }
    } else if (strcmp(info, "Colormap") == 0) {
        if (attr.colormap != None) { printf("0x%lx (not installed)\n", (unsigned long)attr.colormap);
        } else { printf("0x%lx (none)\n", (unsigned long)attr.colormap); }
    }

    if (strcmp(info, "info") == 0) { printf("  Bit Gravity State: %s\n",    bit_grav);
    } else if (strcmp(info, "Bit") == 0) { printf("%s\n",    bit_grav); }
    if (strcmp(info, "info") == 0) { printf("  Window Gravity State: %s\n", win_grav);
    } else if (strcmp(info, "WindowGravity") == 0) { printf("%s\n", win_grav); }
    if (strcmp(info, "info") == 0) {
            printf("  Backing Store State: %s\n",
            attr.backing_store == NotUseful  ? "NotUseful"  :
            attr.backing_store == WhenMapped ? "WhenMapped" : "Always");
    } else if (strcmp(info, "Backing") == 0) {
            printf("%s\n",
            attr.backing_store == NotUseful  ? "NotUseful"  :
            attr.backing_store == WhenMapped ? "WhenMapped" : "Always");
    }
    if (strcmp(info, "info") == 0) { printf("  Save Under State: %s\n",      attr.save_under ? "yes" : "no");
    } else if (strcmp(info, "Save") == 0) { printf("  Save Under State: %s\n",      attr.save_under ? "yes" : "no"); }
    if (strcmp(info, "info") == 0) {
            printf("  Map State: %s\n",
            attr.map_state == IsViewable ? "IsViewable" :
            attr.map_state == IsUnmapped ? "IsUnmapped" : "IsUnviewable");
    } else if (strcmp(info, "Map") == 0) {
            printf("%s\n",
            attr.map_state == IsViewable ? "IsViewable" :
            attr.map_state == IsUnmapped ? "IsUnmapped" : "IsUnviewable");
    }
    if (strcmp(info, "info") == 0) { printf("  Override Redirect State: %s\n", attr.override_redirect ? "yes" : "no");
    } else if (strcmp(info, "Override") == 0) { printf("%s\n", attr.override_redirect ? "yes" : "no"); }

    if (strcmp(info, "info") == 0) {
           printf("  Corners:  +%d+%d  -%d+%d  -%d-%d  +%d-%d\n",
           xabs, yabs,
           sw - xabs - attr.width, yabs,
           sw - xabs - attr.width, sh - yabs - attr.height,
           xabs,   sh - yabs - attr.height);
    } else if (strcmp(info, "Corners") == 0) {
           printf("+%d+%d  -%d+%d  -%d-%d  +%d-%d\n",
           xabs, yabs,
           sw - xabs - attr.width, yabs,
           sw - xabs - attr.width, sh - yabs - attr.height,
           xabs,   sh - yabs - attr.height);
    }
    if (strcmp(info, "info") == 0) { printf("  -geometry %dx%d+%d+%d\n", attr.width, attr.height, xabs, yabs);
    } else if (strcmp(info, "geometry") == 0) { printf("%dx%d+%d+%d\n", attr.width, attr.height, xabs, yabs); }
    if (strcmp(info, "info") == 0 || strcmp(info, "_NET_WM_STATE") == 0 ) {
        if (XGetWindowProperty(display, win, net_wm_state, 0, 1024, False, XA_ATOM,
                           &actual_type, &actual_fmt, &n, &left, &data) == Success && data && n > 0) {
        // printf("  _NET_WM_STATE: ");
        for (unsigned long i = 0; i < n; i++) {
            if (i > 0) printf(" ");
            Atom state = ((Atom*)data)[i];
            char *atom_name = XGetAtomName(display, state);
            if (atom_name) {
                printf("%s", atom_name);
                XFree(atom_name);
            } else {
                printf("0x%lx", (unsigned long)state);
            }
        } printf("\n"); } else { printf("_NET_WM_STATE: (none)\n"); }
    }
    if (data) { XFree(data); } else if (name) { XFree(name); }
    // XCloseDisplay(display);
}

// The main function for working with windows via _NET_WM
int _NET_WM(int argc, char **argv)
{

    display = XOpenDisplay(NULL);
    if (!display) {
        fprintf(stderr, "Cannot open display\n");
        return 1;
    }

    if (argc < 4) {
        fprintf(stderr, "Usage: %s _NET_WM <window_id> <info|hide|show|show_raised|maximize|reduce|rename|fullscreen|unfullscreen|lower_window|state_above0|state_above1|decorated0|decorated1|close>\nExample: %s _NET_WM 0x6000001 info\n", argv[0], argv[0]);
        XCloseDisplay(display);
        return 1;
    }

    Window win = (Window)strtoul(argv[2], NULL, 0);
    char *action = argv[3];

    Atom hidden = XInternAtom(display, "_NET_WM_STATE_HIDDEN", False);
    Atom maxv   = XInternAtom(display, "_NET_WM_STATE_MAXIMIZED_VERT", False);
    Atom maxh   = XInternAtom(display, "_NET_WM_STATE_MAXIMIZED_HORZ", False);
    Atom above  = XInternAtom(display, "_NET_WM_STATE_ABOVE", False);
    Atom fullscreen = XInternAtom(display, "_NET_WM_STATE_FULLSCREEN", False);
    Atom below = XInternAtom(display, "_NET_WM_STATE_BELOW", False);
    Atom shaded = XInternAtom(display, "_NET_WM_STATE_SHADED", False);

    Atom state  = XInternAtom(display, "_NET_WM_STATE", False);
    Atom active = XInternAtom(display, "_NET_ACTIVE_WINDOW", False);

    Atom wm_win_type    = XInternAtom(display, "_NET_WM_WINDOW_TYPE", False);
    Atom wm_win_dock    = XInternAtom(display, "_NET_WM_WINDOW_TYPE_DOCK", False);

    if (strcmp(action, "info") == 0) {
        if (argc == 4) {
            print_window_info(win,argv[3]);
        } else {
            if (argc != 5 || (strcmp(argv[4], "xwininfo") != 0 && strcmp(argv[4], "AbsoluteX") != 0
                && strcmp(argv[4], "AbsoluteY") != 0 && strcmp(argv[4], "RelativeX") != 0
                && strcmp(argv[4], "RelativeY") != 0 && strcmp(argv[4], "Width") != 0
                && strcmp(argv[4], "Height") != 0 && strcmp(argv[4], "Depth") != 0
                && strcmp(argv[4], "Visual") != 0 && strcmp(argv[4], "VisualClass") != 0
                && strcmp(argv[4], "Border") != 0 && strcmp(argv[4], "Class") != 0
                && strcmp(argv[4], "Colormap") != 0 && strcmp(argv[4], "Bit") != 0
                && strcmp(argv[4], "WindowGravity") != 0 && strcmp(argv[4], "Backing") != 0
                && strcmp(argv[4], "Save") != 0 && strcmp(argv[4], "Map") != 0
                && strcmp(argv[4], "Override") != 0 && strcmp(argv[4], "Corners") != 0
                && strcmp(argv[4], "geometry") != 0 && strcmp(argv[4], "_NET_WM_STATE") != 0))
            {
                fprintf(stderr, "Usage: %s _NET_WM <window_id> info <xwininfo|AbsoluteX|AbsoluteY|RelativeX|RelativeY|Width|Height|Depth|Visual|VisualClass|Border|Class|Colormap|Bit|WindowGravity|Backing|Save|Map|Override|Corners|geometry|_NET_WM_STATE>\nExample: %s _NET_WM 0x6000001 info xwininfo\n", argv[0], argv[0]);
                XCloseDisplay(display);
                return 1;
            }
            print_window_info(win,argv[4]);
        }
    }
    else if (strcmp(action, "rename") == 0) {
        if (argc != 5) {
            fprintf(stderr, "Usage: %s _NET_WM <window_id> rename \"New title\"\nExample: %s _NET_WM 0x6000001 rename \"New title test\"\n", argv[0], argv[0]);
            XCloseDisplay(display);
            return 1;
        }
        set_title(win, argv[4]);
    }
    else if (argc != 4) {
        fprintf(stderr, "Usage: %s _NET_WM <window_id> <info|hide|show|show_raised|maximize|reduce|rename|fullscreen|unfullscreen|lower_window|state_above0|state_above1|decorated0|decorated1|close> \nExample: %s _NET_WM 0x6000001 info\n", argv[0], argv[0]);
        XCloseDisplay(display);
        return 1;
    }
    else if (strcmp(action, "hide") == 0) {
        // Iconify = collapse
        XIconifyWindow(display, win, DefaultScreen(display));
    }
    else if (strcmp(action, "show") == 0) {
        // Remove HIDDEN and activate the window
        send_msg(win, 0, hidden, state );
        XMapRaised(display, win);
        XRaiseWindow(display, win);
    }
    else if (strcmp(action, "show_raised") == 0) {
        send_msg(win, 0, hidden, state );
        // Push the window onto the stack
        XMapRaised(display, win);
        XRaiseWindow(display, win);
        send_msg(win, 2, 0, active );
    }
    else if (strcmp(action, "maximize") == 0) {
        // Add both maximization states
        send_msg(win, 1, maxv, state);
        send_msg(win, 1, maxh, state);
    }
    else if (strcmp(action, "reduce") == 0) {
        send_msg(win, 0, maxv, state);
        send_msg(win, 0, maxh, state);
    }
    else if (strcmp(action, "fullscreen") == 0) {
        send_msg(win, 0, hidden, state );
        // Push the window onto the stack
        XMapRaised(display, win);
        XRaiseWindow(display, win);
        send_msg(win, 2, 0, active );
        send_msg(win, 1, fullscreen, state);   // 1 = _NET_WM_STATE_ADD
    }
    else if (strcmp(action, "unfullscreen") == 0) {
        send_msg(win, 0, fullscreen, state);   // 0 = _NET_WM_STATE_ADD
    }
    else if (strcmp(action, "lower_window") == 0) {
        XLowerWindow(display, win);
    }
    else if (strcmp(action, "state_above0") == 0) {
        send_msg(win, 0, above, state );
    }
    else if (strcmp(action, "state_above1") == 0) {
        send_msg(win, 1, above, state );
    }
    else if (strcmp(action, "state_below1") == 0) {
        send_msg(win, 1, below, state);
    }
    else if (strcmp(action, "state_below0") == 0) {
        send_msg(win, 0, below, state);
    }
    else if (strcmp(action, "state_shade1") == 0) {         // collapse to title
        send_msg(win, 1, shaded, state);
    }
    else if (strcmp(action, "state_shade0") == 0) {         // reverse
        send_msg(win, 0, shaded, state);
    }
    else if (strcmp(action, "decorated0") == 0) {
        set_decorations(win, 0);
    }
    else if (strcmp(action, "decorated1") == 0) {
        set_decorations(win, 1);
    }
    else if (strcmp(action, "close") == 0) {
        Atom wm_protocols = XInternAtom(display, "WM_PROTOCOLS", False);
        Atom wm_delete    = XInternAtom(display, "WM_DELETE_WINDOW", False);

        XEvent event = {0};
        event.xclient.type         = ClientMessage;
        event.xclient.window       = win;
        event.xclient.message_type = wm_protocols;
        event.xclient.format       = 32;
        event.xclient.data.l[0]    = wm_delete;
        event.xclient.data.l[1]    = CurrentTime;
        XSendEvent(display, win, False, NoEventMask, &event);
        XFlush(display);
    }
    else {
        fprintf(stderr, "Usage: %s _NET_WM <window_id> <info|hide|show|show_raised|maximize|reduce|rename|fullscreen|unfullscreen|lower_window|state_above0|state_above1|decorated0|decorated1|close>\nExample: %s _NET_WM 0x6000001 info\n", argv[0], argv[0]);
        XCloseDisplay(display);
        return 1;
    }

    XCloseDisplay(display);
    return 0;
}

// Function for viewing the window icon
int _NET_WM_ICON(int argc, char *argv[])
{
    if (argc != 3) {
        fprintf(stderr, "Usage: %s _NET_WM_ICON <window_id>\nExample: %s _NET_WM_ICON 0x6000001\n", argv[0], argv[0]);
        return 1;
    }

    Window win = (Window)strtoul(argv[2], NULL, 0);
    display = XOpenDisplay(NULL);
    if (!display) {
        fprintf(stderr, "Cannot open display\n");
        return 1;
    }

    Atom net_wm_icon = XInternAtom(display, "_NET_WM_ICON", False);

    Atom type_ret;
    int format_ret;
    unsigned long nitems, bytes_left;
    unsigned char *data = NULL;

    if (XGetWindowProperty(display, win,
        net_wm_icon,
        0, ~0L, False,
        XA_CARDINAL,
        &type_ret, &format_ret,
        &nitems, &bytes_left,
        &data) != Success || !data) {
        fprintf(stderr, "Error: Failed to get _NET_WM_ICON property for window %lu\n", win);
        XCloseDisplay(display);
        return 1;
    }

    // the format is always 32, but let's check
    if (format_ret != 32 || type_ret != XA_CARDINAL) {
        fprintf(stderr, "No property format_ret or read error \n");
        XFree(data);
        XCloseDisplay(display);
        return 1;
    }

    unsigned long *pixels = (unsigned long *)data;
    unsigned long len = nitems;
    unsigned long index = 0;

    while (index + 1 < len) {

        unsigned long width = pixels[index++];
        unsigned long height = pixels[index++];

        unsigned long image_size = width * height;

        printf("%lu %lu ", width, height);

        for (unsigned long i = 0; i < image_size; ++i) {
            unsigned long pixel = pixels[index + i];
            //printf("0x%01lx ", pixel);
            printf("0x%08lx ", pixel & 0xffffffff);
            if ((i + 1) % width == 0);
        }
        index += image_size;
        printf("\n");
    }

    XFree(data);
    XCloseDisplay(display);
    return 0;
}

// Function for moving the window
int windowmove(int argc, char *argv[]){
    if (argc != 5) {
        fprintf(stderr, "Usage: %s windowmove <window_id> <window_X> <window_Y> \nExample: %s windowmove 0x6000001 0 0\n", argv[0], argv[0]);
        return 1;
    }

    Window window_id = (Window)strtoul(argv[2], NULL, 0);
    int X = atoi(argv[3]);
    int Y = atoi(argv[4]);

    display = XOpenDisplay(NULL);
    if (!display) {
        fprintf(stderr, "Cannot open display\n");
        return 1;
    }

    XMoveWindow(display, window_id, X, Y);
    XFlush(display);

    printf("Window 0x%lx moved to (%d, %d)\n", window_id, X, Y);

    XCloseDisplay(display);
    return 0;
}

// Function for changing the window size
int windowsize(int argc, char *argv[]){
    if (argc != 5) {
        fprintf(stderr, "Usage: %s windowsize <window_id> <width> <height>\nExample: %s windowsize 0x6000001 800 600\n", argv[0], argv[0]);
        return 1;
    }

    Window window_id = (Window)strtoul(argv[2], NULL, 0);  // Supports hex (0x...) and dec
    int width = atoi(argv[3]);
    int height = atoi(argv[4]);

    display = XOpenDisplay(NULL);
    if (!display) {
        fprintf(stderr, "Cannot open display\n");
        return 1;
    }

    XResizeWindow(display, window_id, width, height);
    XFlush(display);

    printf("Window 0x%lx resized to %dx%d\n", window_id, width, height);

    XCloseDisplay(display);
    return 0;
}

// Function for getting window geometry
int getwindowgeometry(int argc, char *argv[]){
    if (argc != 3) {
        fprintf(stderr, "Usage: %s getwindowgeometry <window_id>\nExample: %s getwindowgeometry 0x6000001\n", argv[0], argv[0]);
        return 1;
    }

    // Open the X11 display
    display = XOpenDisplay(NULL);
    if (!display) {
        fprintf(stderr, "Cannot open display\n");
        return 1;
    }

    Window window = (Window) strtoul(argv[2], NULL, 0);

    Window root;
    int x, y;
    unsigned int width, height, border_width, depth;
    if (XGetGeometry(display, window, &root, &x, &y, &width, &height, &border_width, &depth) == 0) {
        fprintf(stderr, "Failed to get geometry for window %s\n", argv[2]);
        XCloseDisplay(display);
        return 1;
    }

    // Output the results, similar to xdotool getwindowgeometry
    printf("Window %s\n", argv[2]);
    printf("  Position: %d,%d (screen: %d)\n", x, y, XDefaultScreen(display));
    printf("  Geometry: %ux%u\n", width, height);

    XCloseDisplay(display);
    return 0;
}

// Recursive function for searching windows by name
void find_windows_by_name(Display *display, Window window, const char *target_name, Window **found_windows, int *count) {

    Atom net_wm_name_atom = XInternAtom(display, "_NET_WM_NAME", False);
    Atom utf8_string_atom = XInternAtom(display, "UTF8_STRING", False);
    Atom type;
    int format;
    unsigned long nitems, bytes_after;
    unsigned char *prop = NULL;

    if (XGetWindowProperty(display, window, net_wm_name_atom, 0, 1024, False, utf8_string_atom, &type, &format, &nitems, &bytes_after, &prop) == Success && prop) {
        if (strcmp((char *)prop, target_name) == 0) {
            *found_windows = realloc(*found_windows, (*count + 1) * sizeof(Window));
            (*found_windows)[*count] = window;
            (*count)++;
        }
        XFree(prop);
    } else {
        Atom wm_name_atom = XInternAtom(display, "WM_NAME", False);
        if (XGetWindowProperty(display, window, wm_name_atom, 0, 1024, False, XA_STRING, &type, &format, &nitems, &bytes_after, &prop) == Success && prop) {
            if (strcmp((char *)prop, target_name) == 0) {
                *found_windows = realloc(*found_windows, (*count + 1) * sizeof(Window));
                (*found_windows)[*count] = window;
                (*count)++;
            }
            XFree(prop);
        }
    }

    Window root, parent, *children;
    unsigned int nchildren;
    if (XQueryTree(display, window, &root, &parent, &children, &nchildren)) {
        for (unsigned int i = 0; i < nchildren; i++) {
            find_windows_by_name(display, children[i], target_name, found_windows, count);
        }
        if (children) XFree(children);
    }
}

// Function for recursively traversing windows and searching by PID
void find_windows_by_pid(Display *display, Window window, unsigned long target_pid, Window **found_windows, int *count) {
    Atom type;
    int format;
    unsigned long nitems, bytes_after;
    unsigned char *prop = NULL;
    Atom pid_atom = XInternAtom(display, "_NET_WM_PID", False);

    if (XGetWindowProperty(display, window, pid_atom, 0, 1, False, XA_CARDINAL, &type, &format, &nitems, &bytes_after, &prop) == Success && prop) {
        unsigned long *pid = (unsigned long *)prop;
        if (*pid == target_pid) {
            *found_windows = realloc(*found_windows, (*count + 1) * sizeof(Window));
            (*found_windows)[*count] = window;
            (*count)++;
        }
        XFree(prop);
    }

    Window root, parent, *children;
    unsigned int nchildren;
    if (XQueryTree(display, window, &root, &parent, &children, &nchildren)) {
        for (unsigned int i = 0; i < nchildren; i++) {
            find_windows_by_pid(display, children[i], target_pid, found_windows, count);
        }
        if (children) XFree(children);
    }

}

// Function for searching windows by name or PID
int search(int argc, char *argv[]) {

    if (argc != 4) {
        fprintf(stderr, "Usage: %s [ search --name <title> | search --pid <pid>] \nExample: %s search --pid 25957\n", argv[0], argv[0]);
        return 1;
    }

    display = XOpenDisplay(NULL);
    if (!display) {
        fprintf(stderr, "Cannot open display\n");
        return 1;
    }

    Window root = DefaultRootWindow(display);
    Window *found_windows = NULL;
    int count = 0;


    if (strcmp(argv[2], "--name") == 0) {

        const char *target_name = argv[3];

        find_windows_by_name(display, root, target_name, &found_windows, &count);

        if (count == 0) {
            fprintf(stderr, "No windows found with name: %s\n", target_name);
            XCloseDisplay(display);
            free(found_windows);
            return 1;
        }

        for (int i = 0; i < count; i++) {
            printf("%lu\n", (unsigned long)found_windows[i]);
        }
    }

    if (strcmp(argv[2], "--pid") == 0) {

        unsigned long pid = strtoul(argv[3], NULL, 10);

        find_windows_by_pid(display, root, pid, &found_windows, &count);

        if (count == 0) {
            fprintf(stderr, "No windows found for PID %lu\n", pid);
            XCloseDisplay(display);
            free(found_windows);
            return 1;
        }

        // Output the found windows in dec format, in one line with a prefix
        for (int i = 0; i < count; i++) {
            printf("%lu\n", (unsigned long)found_windows[i]);
        }
    }

    XCloseDisplay(display);
    free(found_windows);
    return 0;
}

// Function for setting an icon for a window
int xseticon(int argc, char **argv) {

    if (argc < 6) {
        fprintf(stderr, "Usage: %s xseticon <window_id> <icon_data1> <icon_data2> ...\nExample: %s xseticon 0x6000001 2 2 0xffff0000 0x0000ffff 0xcccc0b09 0x10101010\n", argv[0], argv[0]);
        return 1;
    }

    display = XOpenDisplay(NULL);
    if (!display) {
        fprintf(stderr, "Cannot open display\n");
        return 1;
    }

    Window win = (Window)strtoul(argv[2], NULL, 0);
    Atom wm_icon = XInternAtom(display, "_NET_WM_ICON", False);

    if (wm_icon == None) {
        fprintf(stderr, "Cannot find _NET_WM_ICON atom\n");
        XCloseDisplay(display);
        return 1;
    }

    int nitems = argc - 3;  // argv[0] - program name, argv[1] - xseticon, argv[2] - window_id, the rest are data
    unsigned long *icon_data = malloc(nitems * sizeof(unsigned long));

    if ( !icon_data ) { fprintf(stderr, "Error: Failed to allocate memory malloc for ARGB icon data\n"); XCloseDisplay(display); return 0; }

    if ( nitems != atoi(argv[3]) * atoi(argv[4]) + 2 ) {
        fprintf(stderr, "Data entry error (ARGB format)\n");
        XCloseDisplay(display);
        free(icon_data);
        return 1;
    }

    for (int i = 0; i < nitems; i++) {
        icon_data[i] = strtoul(argv[i + 3], NULL, 0); // argv[3] - the first data element
    }

    XChangeProperty(display, win, wm_icon, XA_CARDINAL, 32, PropModeReplace,
    (unsigned char *)icon_data, nitems);

    XCloseDisplay(display);
    free(icon_data);
    printf("Icon set for window %lu (xseticon emulation)\n", win);

    return 0;
}

int get_number_in_range(const char *str, int min, int max) {

    const char *ptr = str;
    while (*ptr) {
        if (!isdigit((unsigned char)*ptr)) {
            return 20;
        }
        ptr++;
    }

    int num = atoi(str);
    if (num >= min && num <= max) {
        return num;
    } else {
        return 20;
    }
}

typedef struct {
    int argc_thread;
    char **argv_thread;
    int ret_thread;
} xseticon_args_t;

void* thread_func(void* arg) {
    xseticon_args_t* args = (xseticon_args_t*)arg;
    pid_t pid = fork();
    if (pid == 0) {
        int ret = xseticon(args->argc_thread, args->argv_thread);
        exit(ret);
    } else if (pid > 0) {
        int status;
        waitpid(pid, &status, 0);
        if (WIFEXITED(status)) {
            args->ret_thread = WEXITSTATUS(status);
        } else {
            args->ret_thread = -1;
        }
    } else {
        perror("fork");
        args->ret_thread = -2;
    }

    return NULL;
}

// Function for setting a gif icon for a window
int xseticon_gif(int argc, char **argv) {

    int frame = 50000;

    if (argc == 5){
        frame = (int)(1000000.0 / get_number_in_range(argv[4], 1, 120));
        printf("Frame rates greater than 50 may not be supported by the system; 20 is recommended.\nExample: %s xseticon_gif 0x6000001 /home/sysadmin/Desktop/test/imege_6/imege_6.txt 20\n", argv[0]);
    } else if (argc != 4) {
        fprintf(stderr, "Usage: %s xseticon_gif <window_id> <file> [<frame_rate 1-120> — optional, otherwise 20]\nFrame rates greater than 50 may not be supported by the system; 20 is recommended.\nExample: %s xseticon_gif 0x6000001 /home/sysadmin/Desktop/test/imege_6/imege_6.txt\n", argv[0], argv[0]);
        return 1;
    }

    size_t total_size = strlen(argv[1]) + strlen(argv[1]) + strlen(argv[2]) + 2 + 1;
    char *window_id_str = malloc(total_size);

    if ( !window_id_str ) { fprintf(stderr, "Error: Failed to allocate memory malloc\n");  return 1; }

    snprintf(window_id_str, total_size, "%s %s %s", argv[1], argv[1], argv[2]); // window_id

    const char *filename = argv[3];      // файл

    FILE *file = fopen(filename, "r");
    if (!file) {
        free(window_id_str);
        fprintf(stderr, "Failed to open file %s\n", filename);
        return 1;
    }

    fseek(file, 0, SEEK_END);
    long length = ftell(file);
    rewind(file);
    char *buffer = malloc(length + 1);

    if ( !buffer ) { free(window_id_str); fprintf(stderr, "Error: Failed to allocate memory malloc\n");  return 1; }

    size_t read_size = fread(buffer, 1, length, file);
    buffer[read_size] = '\0';

    fclose(file);

    // In the file we look for the last '[' and ']'
    char *last_bracket1 = strrchr(buffer, '[');
    char *last_bracket2 = strrchr(buffer, ']');
    if (!last_bracket1 || !last_bracket2 || last_bracket1+1 >= last_bracket2 ) {
        free(window_id_str);
        free(buffer);
        fprintf(stderr, "Invalid format: missing or incorrect brackets\n");
        return 1;
    }

    int num_len = last_bracket2 - last_bracket1 - 1;

    char num_str[16];
    strncpy(num_str, last_bracket1 + 1, num_len);
    num_str[num_len] = '\0';

    int index = atoi(num_str);
    char ***icon_items = malloc(sizeof(char**) * (index+1));

    if ( !icon_items ) { free(window_id_str); free(buffer); fprintf(stderr, "Error: Failed to allocate memory malloc\n");  return 1; }

    int icon_number[index];
    size_t length_id = strlen(window_id_str);

    for (int i = 0; i <= index; i++)
    {
        char pattern[20];
        snprintf(pattern, 20, "[%d]=\"", i);

        char *start_ptr = strstr(buffer, pattern);
        if (start_ptr == NULL) {
            free(window_id_str);
            free(buffer);
            for (int n = 0; n < i; n++) {
                for (int j = 0; icon_items[n][j] != NULL; j++) {
                    free(icon_items[n][j]);
                }
                free(icon_items[n]);
            }
            free(icon_items);
            fprintf(stderr, "Invalid format: missing or incorrect brackets\n");
            return 1;
        }

        start_ptr += strlen(pattern);

        char *end_ptr = strchr(start_ptr, '"');
        if (end_ptr == NULL) {
            free(window_id_str);
            free(buffer);
            for (int n = 0; n < i; n++) {
                for (int j = 0; icon_items[n][j] != NULL; j++) {
                    free(icon_items[n][j]);
                }
                free(icon_items[n]);
            }
            free(icon_items);
            fprintf(stderr, "Invalid format: missing or incorrect brackets\n");
            return 1;
        }
        size_t length = end_ptr - start_ptr;
        char *content = malloc(length + length_id +2);

        if ( !content ) { free(window_id_str); free(buffer); for (int n = 0; n < i; n++) { for (int j = 0; icon_items[n][j] != NULL; j++) { free(icon_items[n][j]); } free(icon_items[n]); } free(icon_items); fprintf(stderr, "Error: Failed to allocate memory malloc\n");  return 1; }

        snprintf(content, length + length_id +2, "%s %.*s", window_id_str, (int)length, start_ptr);

        char *content_copy = strdup(content); // Create a copy for parsing
        int count = 0;
        char *token = strtok(content_copy, " \t\n\r");
        while (token != NULL) {
            count++;
            token = strtok(NULL, " \t\n\r");
        }
        free(content_copy);

        icon_number[i]= count;
        char **argv = malloc(sizeof(char*) * (count + 1));

        if ( !argv ) { free(window_id_str); free(buffer); for (int n = 0; n < i; n++) { for (int j = 0; icon_items[n][j] != NULL; j++) { free(icon_items[n][j]); } free(icon_items[n]); } free(icon_items); free(content); fprintf(stderr, "Error: Failed to allocate memory malloc\n");  return 1; }

        int index1 = 0;
        token = strtok(content, " \t\n\r");
        while (token != NULL) {
            argv[index1++] = strdup(token);
            token = strtok(NULL, " \t\n\r");
        }
        argv[index1] = NULL;

        free(content);
        icon_items[i] = argv;
    }

    free(window_id_str);
    free(buffer);
    int test = 0;
    while(!test) {

        for (int i = 0; i <= index; i++) {

            //test = xseticon(icon_number[i], icon_items[i]);

            pthread_t thread_id;

            xseticon_args_t args;
            args.argc_thread = icon_number[i];
            args.argv_thread = icon_items[i];

            int rc = pthread_create(&thread_id, NULL, thread_func, &args);
            if (rc == 0) {
                pthread_join(thread_id, NULL);
                test = args.ret_thread;
            } else {
                perror("pthread_create");
                test = -2;
            }

            if ( test != 0 ) {
                break;
            }
            if ( index == 0 ){
                printf("The %s file contains a single image that was transferred once to the window %s.\n", argv[3], argv[2]);
                test = 1;
                break;
            }
            usleep(frame); // 20 frames per second
        }
    }

    for (int i = 0; i <= index; i++) {
        for (int j = 0; icon_items[i][j] != NULL; j++) {
            free(icon_items[i][j]);
        }
        free(icon_items[i]);
    }
    free(icon_items);

    return 0;
}

// The main function of the program
int main(int argc, char *argv[]) {

    if (argc < 2 ) {
        fprintf(stderr, "Usage: %s <-help> | <windowmove> | <windowsize> | <getwindowgeometry> | <search> | <xseticon> | <xseticon_gif> | <_NET_WM_ICON> | <_NET_WM> \n", argv[0]);
        return 1;
    }

    // Handling -help and --help
    if (strcmp(argv[1], "-help") == 0 || strcmp(argv[1], "--help") == 0 || strcmp(argv[1], "-h") == 0 || strcmp(argv[1], "--h") == 0) {
        print_help(argv[0]);
        return 0;
    }

    // Checking the first argument (argv[1]) на "windowmove"
    if (strcmp(argv[1], "windowmove") == 0) {
        return windowmove(argc, argv);
    }

    // Checking the first argument (argv[1]) на "windowsize"
    if (strcmp(argv[1], "windowsize") == 0) {
        return windowsize(argc, argv);
    }

    // Checking the first argument (argv[1]) на "getwindowgeometry"
    if (strcmp(argv[1], "getwindowgeometry") == 0) {
        return getwindowgeometry(argc, argv);
    }

    // Checking the first argument (argv[1]) на "search"
    if (strcmp(argv[1], "search") == 0) {
        return search(argc, argv);
    }

    // Checking the first argument (argv[1]) на "xseticon"
    if (strcmp(argv[1], "xseticon") == 0) {
        return xseticon(argc, argv);
    }

    // Checking the first argument (argv[1]) на "xseticon_gif"
    if (strcmp(argv[1], "xseticon_gif") == 0) {
        return xseticon_gif(argc, argv);
    }

    // Checking the first argument (argv[1]) на "_NET_WM_ICON"
    if (strcmp(argv[1], "_NET_WM_ICON") == 0) {
        return _NET_WM_ICON(argc, argv);
    }

    // Checking the first argument (argv[1]) на "_NET_WM"
    if (strcmp(argv[1], "_NET_WM") == 0) {
        return _NET_WM(argc, argv);
    }

    fprintf(stderr, "Usage: %s <-help> | <windowmove> | <windowsize> | <getwindowgeometry> | <search> | <xseticon> | <xseticon_gif> | <_NET_WM_ICON> | <_NET_WM> \n", argv[0]);
    return 1;
}
