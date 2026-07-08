#!/bin/bash

#sudo apt install xdotool xseticon librsvg2-bin libxdo3
#sudo apt install x11-utils
#sudo apt install -y xdotool;

check_deps() {

    if ! command -v gcc >/dev/null 2>&1; then
        echo "Error: Install gcc (sudo apt install build-essential or sudo pacman -S base-devel)"
        exit 1
    fi

}

sync_buffer_xephyr() {

if ! command -v xclip >/dev/null 2>&1; then
    echo "Error: Install xclip (sudo apt install xclip or sudo pacman -S xclip)"
    exit 1
fi

primary_buffer=""
clipboard_buffer=""

check_pid_alive() {
    if ! kill -0 "$XEYPH_PID" 2>/dev/null; then
        echo "The XEYPH has terminated and sync_buffer_xephyr OFF"
        exit 0
    fi
}

while true; do

    check_pid_alive;

    buffer_primary_unique_id="$({ xclip -o -selection primary -display :$unique_id ; } 2>/dev/null)"
    buffer_primary_DISPLAY_OLD="$({ xclip -o -selection primary -display $DISPLAY_OLD ; } 2>/dev/null)"
    buffer_clipboard_unique_id="$({ xclip -o -selection clipboard -display :$unique_id ; } 2>/dev/null)"
    buffer_clipboard_DISPLAY_OLD="$({ xclip -o -selection clipboard -display $DISPLAY_OLD ; } 2>/dev/null)"

    if [[ "$primary_buffer" != "$buffer_primary_DISPLAY_OLD" ]]; then
        primary_buffer="$buffer_primary_DISPLAY_OLD"
        check_pid_alive && echo "$buffer_primary_DISPLAY_OLD" | xclip -selection primary -i -display :$unique_id
    elif [[ "$primary_buffer" != "$buffer_primary_unique_id" ]]; then
        primary_buffer="$buffer_primary_unique_id"
        check_pid_alive && echo "$buffer_primary_unique_id" | xclip -selection primary -i -display $DISPLAY_OLD
    fi

    if [[ "$clipboard_buffer" != "$buffer_clipboard_DISPLAY_OLD" ]]; then
        clipboard_buffer="$buffer_clipboard_DISPLAY_OLD"
        check_pid_alive && echo "$buffer_clipboard_DISPLAY_OLD" | xclip -selection clipboard -i -display :$unique_id
    elif [[ "$clipboard_buffer" != "$buffer_clipboard_unique_id" ]]; then
        clipboard_buffer="$buffer_clipboard_unique_id"
        check_pid_alive && echo "$buffer_clipboard_unique_id" |  xclip -selection clipboard -i -display $DISPLAY_OLD
    fi

# echo "$({ xclip -o -selection primary -display :$unique_id ; } 2>&1)"
# echo "$({ xclip -o -selection clipboard -display :$unique_id ; } 2>&1)"
#
# echo "$({ xclip -o -selection primary -display $DISPLAY_OLD ; } 2>&1)"
# echo "$({ xclip -o -selection clipboard -display $DISPLAY_OLD ; } 2>&1)"
sleep 0.5;
done
}

make_xdotool_xseticon() {
if [ -f "$SCRIPT_DIR/xdotool_xseticon" ]; then
        echo "Уже существует $SCRIPT_DIR/xdotool_xseticon"
        #sudo rm -f $SCRIPT_DIR/xdotool_xseticon.c  # Cleaning
        else
            cat > "$SCRIPT_DIR/xdotool_xseticon.c" << EOF
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
EOF
        # Compilation
        if gcc -o "$SCRIPT_DIR/xdotool_xseticon" "$SCRIPT_DIR/xdotool_xseticon.c" -lX11 2>/dev/null; then
            echo "Compiling $SCRIPT_DIR/xdotool_xseticon"
            rm -f "$SCRIPT_DIR/xdotool_xseticon.c"  # Cleaning
            return 0
        else
            echo "Error compiling $SCRIPT_DIR/xdotool_xseticon.c: check gcc and X11-dev (sudo apt install libx11-dev or sudo pacman -S libx11)"
            rm -f "$SCRIPT_DIR/xdotool_xseticon.c"
            return 1
        fi
    fi

}


input_png="76 76 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x394aa4d9 0x773197d1 0xaf2190ce 0xd2128acb 0xee158bd0 0xff0e88ce 0xff0082cb 0xff0081cb 0xff0080ca 0xff0080ca 0xff0c86ca 0xee1186cb 0xd81686cb 0xb7228bc9 0x7f3290cb 0x3c3c99cd 0x04acdafd 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x1c61c4fb 0x72269ee0 0xd8259ee1 0xff0083cd 0xff0083ce 0xff0084d2 0xff0089d6 0xff0084d0 0xff137abb 0xff2c6fad 0xff3868a1 0xff40659d 0xff40649c 0xff3b669d 0xff2b6ca9 0xff1574b5 0xff007fc8 0xff0081d0 0xff007fcc 0xff007bc8 0xff0076c2 0xe52597dc 0x7f2895da 0x2c52ace0 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x6835a4e3 0xea219de3 0xff0082cd 0xff0087d4 0xff0088d2 0xff306ea9 0xff6e547d 0xffab3953 0xffec1c26 0xffff0b09 0xffff1010 0xffed1b23 0xffdf202c 0xffd22534 0xffd32534 0xffdc202e 0xffea1c23 0xffff1114 0xffff0b0a 0xfff2191f 0xffb2344c 0xff744d75 0xff3763a0 0xff0079c6 0xff007bca 0xff0074c3 0xf60d7cc0 0x702994d6 0x0a81d3ff 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x0a8ad7ff 0x9635a5e5 0xff0183cb 0xff0085d0 0xff0084cf 0xff45679b 0xffa53c57 0xffff0e11 0xfff4181f 0xffae344d 0xff724b73 0xff36629e 0xff007bc5 0xff0088da 0xff0090d9 0xff0798db 0xff139adc 0xff149adc 0xff0894d9 0xff008ed9 0xff0083d3 0xff0078c5 0xff2f609d 0xff6b4974 0xffa73350 0xffea1c24 0xffff0f0e 0xffb0334d 0xff505a8d 0xff0075bf 0xff0076c6 0xff0076c0 0x9f2890d4 0x0e57b4f4 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x86229adf 0xff0d89ce 0xff0084d3 0xff117cbd 0xff7f4c72 0xffe3202b 0xffe31f2a 0xff824468 0xff2a67a3 0xff0382c8 0xff32aae2 0xff74c6ed 0xffa8dcf2 0xffd5edf7 0xfffafbfc 0xfffefffd 0xfff3f9fa 0xfff2f8fc 0xfff1fafc 0xfff3f8fb 0xfffefefe 0xfffafcfc 0xffdceff6 0xffaddaf0 0xff7ac4e8 0xff39a6dd 0xff077bc3 0xff2160a0 0xff79436b 0xffdb222e 0xffeb1c25 0xff8b4165 0xff1c6aad 0xff0076c5 0xff0474bf 0x98248bd3 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x5440b5f5 0xee0d85cb 0xff0083d0 0xff0c7dc1 0xff924465 0xfffa161b 0xffb4334a 0xff3a6299 0xff0488cf 0xff55b9e9 0xffb6e2f3 0xfffcfffe 0xffe8f5f9 0xffadd9ef 0xff7bc2e5 0xff4eacdc 0xff2a9cd7 0xff1491d2 0xff0c8dd0 0xff0a8bd1 0xff0a8acf 0xff0c8ace 0xff138dcf 0xff2797d3 0xff48a5d8 0xff75bae1 0xffa6d2eb 0xffe2f1f8 0xffffffff 0xffc1e4f4 0xff60b5e3 0xff0781c7 0xff2e5897 0xffa7354f 0xfffb1619 0xffa13855 0xff166aaf 0xff0073c2 0xf70a73bc 0x683aa1e6 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0xa02298dc 0xff0080c9 0xff0087d5 0xff6b547e 0xfffb161b 0xffc52b3e 0xff196dad 0xff0692d8 0xff94d2ef 0xffffffff 0xfff6fcfb 0xff7bc1e6 0xff289cd8 0xff008bd1 0xff0086d0 0xff0088cf 0xff0089d0 0xff008ad0 0xff008acf 0xff008ad0 0xff0088ce 0xff0087cf 0xff0086ce 0xff0085cd 0xff0083cb 0xff0081ca 0xff007ec8 0xff007bc6 0xff007cc8 0xff218ecc 0xff6fb5de 0xffebf5f9 0xfffffffe 0xffa5d6ed 0xff0e88ce 0xff0e61aa 0xffb33046 0xffff1418 0xff834369 0xff0074c4 0xff006ebd 0xbe2689d1 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x245ec2fc 0xef1084c9 0xff0082cf 0xff2072b4 0xffdc242f 0xffed1c25 0xff2f669f 0xff0091da 0xffb5e0f2 0xffffffff 0xffafdaef 0xff2c9fd7 0xff0085ce 0xff0087cf 0xff008bd1 0xff008cd3 0xff008dd4 0xff008dd4 0xff008dd4 0xff008dd3 0xff008dd2 0xff018cd1 0xff018bd1 0xff008ad0 0xff008acf 0xff0088ce 0xff0086cd 0xff0085cd 0xff0084cc 0xff0083cb 0xff0080ca 0xff007ec6 0xff007ac4 0xff0075c3 0xff238dca 0xff9fcde6 0xffffffff 0xffc7e4f3 0xff0988cf 0xff1c5c9d 0xffda222f 0xffec1e24 0xff325e9a 0xff006fc4 0xf1046db9 0x353d95d5 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x4c3ba2e1 0xff037fc7 0xff0085d2 0xff6d527d 0xffff1011 0xff7d496f 0xff0083d2 0xff84ccec 0xffffffff 0xffa1d3ed 0xff1695d4 0xff0085ce 0xff008ad1 0xff008dd3 0xff008dd3 0xff018ed4 0xff008fd5 0xff008fd5 0xff018fd6 0xff008fd5 0xff008fd5 0xff018ed4 0xff008dd3 0xff008dd2 0xff008cd1 0xff018bd0 0xff008ad0 0xff0188ce 0xff0186ce 0xff0085cc 0xff0084cc 0xff0083cb 0xff0080c9 0xff007fc7 0xff017ec6 0xff007ac3 0xff0073c1 0xff0c7ec4 0xff8bc1e2 0xffffffff 0xff9fd0ea 0xff0074c4 0xff634775 0xffff1210 0xff884064 0xff0071c2 0xff046cb9 0x612079bc 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x581f88ca 0xff037fc8 0xff007fc9 0xff9e3e5c 0xfffd1519 0xff2666a3 0xff1099db 0xfff7fcfb 0xffe9f4f8 0xff2598d6 0xff0082cd 0xff008bd0 0xff018cd2 0xff008ed4 0xff008ed5 0xff008fd6 0xff0190d6 0xff0090d6 0xff0191d7 0xff0191d7 0xff0190d6 0xff0090d6 0xff0090d6 0xff008fd6 0xff008ed4 0xff008dd3 0xff008cd2 0xff008bd0 0xff008acf 0xff0088ce 0xff0086cd 0xff0084cc 0xff0083cb 0xff0082ca 0xff0080c8 0xff007fc7 0xff007dc5 0xff017bc4 0xff0079c3 0xff0070bf 0xff1582c5 0xffd6e9f3 0xfffffffe 0xff2791d2 0xff125ca4 0xffef1a21 0xffb72e47 0xff026ab5 0xff0069b7 0x853285c1 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x6e3696ce 0xff007cc7 0xff047ac3 0xffc82c3e 0xffde212e 0xff0078c5 0xff70c0e7 0xffffffff 0xff73bde3 0xff0080ca 0xff0088cf 0xff008cd1 0xff008dd2 0xff008ed6 0xff008fd5 0xff0190d6 0xff0191d7 0xff0191d7 0xff0192d7 0xff0093d8 0xff0093d8 0xff0092d8 0xff0192d7 0xff0191d7 0xff0191d7 0xff0090d6 0xff018fd5 0xff008dd4 0xff008cd1 0xff008bd0 0xff0089cf 0xff0188ce 0xff0086cd 0xff0084cc 0xff0083cb 0xff0081ca 0xff007fc8 0xff007ec6 0xff017cc4 0xff007ac3 0xff0079c2 0xff0075bf 0xff006cb9 0xff59a3d2 0xffffffff 0xff8fc6e5 0xff0068bb 0xffc5283a 0xffdd212d 0xff0f63ae 0xff0065b5 0x86297ebf 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x581e87c8 0xff007ac6 0xff0b78be 0xffdb2432 0xffb0334b 0xff007fce 0xffb6dff2 0xfffbfcfc 0xff1d93d2 0xff0082cd 0xff008acf 0xff008bd0 0xff008dd1 0xff008dd4 0xff018fd5 0xff0190d6 0xff0191d7 0xff0093d8 0xff0094d8 0xff0094d8 0xff0095d9 0xff0195d9 0xff0094d9 0xff0094d8 0xff0094d8 0xff0192d7 0xff0191d7 0xff0190d6 0xff008fd5 0xff008dd3 0xff008cd1 0xff008bd0 0xff0089cf 0xff0087ce 0xff0084cc 0xff0084cc 0xff0082ca 0xff0080c8 0xff007fc6 0xff017dc5 0xff007bc4 0xff0079c2 0xff0178c1 0xff0076c0 0xff006eba 0xff0c77bf 0xffebf4f8 0xffd0e7f3 0xff006fc0 0xff943658 0xffea1d27 0xff1660a9 0xff0065b6 0x843283c3 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x3d2795db 0xff067cc4 0xff027bc1 0xffda2434 0xffac344d 0xff0284ce 0xffc7e4f2 0xffdaeef6 0xff0586cd 0xff0084cd 0xff0188ce 0xff008bd0 0xff008cd1 0xff008dd3 0xff008fd5 0xff0190d6 0xff0192d7 0xff0093d8 0xff0095d9 0xff0096d9 0xff0196da 0xff0196da 0xff0097db 0xff0196da 0xff0096da 0xff0095d9 0xff0094d9 0xff0193d8 0xff0191d7 0xff0190d6 0xff008ed4 0xff008dd2 0xff008cd1 0xff008ad0 0xff0088ce 0xff0086cd 0xff0084cc 0xff0083cb 0xff0081c9 0xff007fc7 0xff007ec5 0xff007bc4 0xff007ac3 0xff0079c2 0xff0077c0 0xff0075be 0xff0071bb 0xff006eba 0xffc2dcec 0xffe1f1f6 0xff0679c3 0xff953357 0xffea1c26 0xff1061aa 0xff0063b4 0x5d1771b8 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x1a50b3f2 0xff047bc4 0xff007ac6 0xffc72b3e 0xffb33249 0xff0183cc 0xffd0eaf4 0xffc9e5f2 0xff0080ca 0xff0083cc 0xff0187ce 0xff008acf 0xff008bd0 0xff008dd2 0xff008ed4 0xff0090d6 0xff0191d7 0xff0093d8 0xff0095d9 0xff0096da 0xff0097db 0xff0098dc 0xff0098dc 0xff0099dd 0xff0098dc 0xff0097dc 0xff0097da 0xff0095d9 0xff0094d9 0xff0093d8 0xff0091d7 0xff008fd5 0xff008ed3 0xff008cd1 0xff008bd0 0xff0089cf 0xff0187ce 0xff0084cc 0xff0083cb 0xff0082ca 0xff007fc8 0xff007fc6 0xff017cc4 0xff007ac3 0xff0079c2 0xff0077c1 0xff0075bf 0xff0173bd 0xff0071ba 0xff0067b6 0xffacd1e8 0xffe9f4f7 0xff0676c1 0xff963557 0xffdc212e 0xff0363b2 0xff0264b3 0x313689cd 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0xe9127fc3 0xff007dcb 0xff973f5e 0xffdf212b 0xff007bc9 0xffc4e3f3 0xffcae5f1 0xff007bc7 0xff0083cc 0xff0185cd 0xff0188ce 0xff008ad0 0xff008bd0 0xff008dd3 0xff008fd5 0xff0190d6 0xff0092d7 0xff0094d8 0xff0196da 0xff0098dc 0xff0098dd 0xff009add 0xff009ade 0xff009bde 0xff009ade 0xff0099dd 0xff0098dc 0xff0097da 0xff0196da 0xff0094d8 0xff0192d7 0xff0190d6 0xff008fd5 0xff008dd2 0xff008bd0 0xff0089cf 0xff0187ce 0xff0085cc 0xff0084cc 0xff0082ca 0xff017fc9 0xff007fc6 0xff007dc4 0xff007bc3 0xff0079c2 0xff0078c1 0xff0075be 0xff0074be 0xff0072bb 0xff006fba 0xff0065b5 0xffadcfe7 0xffe1f0f5 0xff006abc 0xffc72639 0xffb72c45 0xff0067ba 0xf60463b1 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x982492d5 0xff0078c7 0xff65517f 0xffff1516 0xff006fbb 0xffb0daef 0xffdfeff5 0xff007cc8 0xff0082cb 0xff0084cc 0xff0086cd 0xff0089cf 0xff008bd0 0xff008cd1 0xff008ed4 0xff0090d6 0xff0191d7 0xff0094d8 0xff0095d9 0xff0097db 0xff0098dc 0xff019ade 0xff019cdf 0xff019cdf 0xff019cdf 0xff019cdf 0xff019cdf 0xff009add 0xff0098dc 0xff0097da 0xff0095d9 0xff0092d8 0xff0090d6 0xff008fd5 0xff008dd2 0xff008cd1 0xff008ad0 0xff0088ce 0xff0085cd 0xff0184cc 0xff0183cb 0xff0080c9 0xff007fc6 0xff007dc5 0xff007bc3 0xff007ac3 0xff0177c1 0xff0176bf 0xff0074bd 0xff0072bb 0xff0070ba 0xff006db9 0xff0064b2 0xffc2dded 0xffd0e6f2 0xff005eb5 0xfff01b22 0xff873b61 0xff0063b7 0xbd0c65b4 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x4d52b5f1 0xff0076c1 0xff176eb5 0xffff1213 0xff305c98 0xff65b6e3 0xfffffffd 0xff0783c9 0xff007fc9 0xff0083cb 0xff0084cc 0xff0087cd 0xff0089cf 0xff008bd0 0xff008cd1 0xff008fd5 0xff0090d6 0xff0192d7 0xff0094d8 0xff0096da 0xff0097dc 0xff0099dd 0xff009bde 0xff019de0 0xff009de0 0xff009de0 0xff019de0 0xff019cdf 0xff009bde 0xff0099dc 0xff0097da 0xff0095d9 0xff0093d8 0xff0091d7 0xff008fd5 0xff008ed4 0xff008cd2 0xff018bd0 0xff0088ce 0xff0085cd 0xff0084cc 0xff0082cb 0xff0080c9 0xff007fc6 0xff007dc5 0xff017bc4 0xff007ac3 0xff0178c1 0xff0176bf 0xff0074be 0xff0173bc 0xff0070ba 0xff006eb9 0xff006cb9 0xff0067b5 0xffeaf4f8 0xff90c0e1 0xff12529b 0xffff1513 0xff325393 0xff005fb2 0x672a7dc8 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0xe30d79c0 0xff007aca 0xffd12735 0xff8b3f63 0xff098cd2 0xffffffff 0xff2590cd 0xff007dc5 0xff0181ca 0xff0083cb 0xff0084cc 0xff0186cd 0xff0089cf 0xff018bd0 0xff008dd2 0xff008fd5 0xff0191d7 0xff0092d7 0xff0094d9 0xff0097da 0xff0097dc 0xff009ade 0xff019cdf 0xff019de0 0xff019fe1 0xff009fe2 0xff009ee1 0xff019de0 0xff019bde 0xff0199dd 0xff0098db 0xff0196da 0xff0093d8 0xff0091d7 0xff0090d6 0xff008ed5 0xff018cd3 0xff018bd0 0xff0088ce 0xff0085cd 0xff0084cc 0xff0083cb 0xff0080c9 0xff007fc6 0xff017dc5 0xff017bc4 0xff007ac3 0xff0078c1 0xff0176bf 0xff0074be 0xff0173bc 0xff0070ba 0xff006eb9 0xff006db8 0xff0068b6 0xff0c6eb8 0xffffffff 0xff2586c8 0xff644071 0xffec1d25 0xff0063b6 0xf80b64b1 0x017dc2f8 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x7a2c94d9 0xff0075c2 0xff5b5283 0xfff6181f 0xff0073c4 0xffeef7fa 0xff80bce0 0xff0077c2 0xff007fc7 0xff0181ca 0xff0083cb 0xff0084cc 0xff0186cd 0xff0087ce 0xff0084cd 0xff008ad1 0xff008fd5 0xff0191d7 0xff0092d7 0xff0094d9 0xff0097da 0xff0097dc 0xff009ade 0xff009cdf 0xff009de0 0xff009fe1 0xff00a0e2 0xff009fe1 0xff009de0 0xff009bde 0xff0099dd 0xff0098db 0xff0196da 0xff0093d8 0xff0091d7 0xff0090d6 0xff008ed4 0xff018cd3 0xff018bd0 0xff0088ce 0xff0086cd 0xff0084cc 0xff0083cb 0xff0180c9 0xff007fc6 0xff017ec5 0xff017bc4 0xff007ac3 0xff0078c1 0xff0176bf 0xff0074be 0xff0173bc 0xff0070ba 0xff006eb9 0xff006db8 0xff006bb7 0xff0063b2 0xff5a9ccf 0xffffffff 0xff0063b9 0xffdb202d 0xff803a65 0xff005eb3 0x97237bc6 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0xf00976bf 0xff0372bb 0xfff2191f 0xff3b5690 0xff74bbe3 0xfff3f9fa 0xff0073c0 0xff007ec5 0xff007fc7 0xff0181ca 0xff0083cb 0xff0084cc 0xff0085cd 0xff45a8db 0xffeff6fa 0xff4aaede 0xff0085d0 0xff008cd4 0xff0091d7 0xff0094d9 0xff0196da 0xff0098db 0xff019add 0xff009bde 0xff019cdf 0xff009de0 0xff009de0 0xff019de0 0xff019cdf 0xff019ade 0xff0098dc 0xff0098db 0xff0095d9 0xff0093d8 0xff0191d7 0xff0090d6 0xff008ed4 0xff018cd1 0xff018bd0 0xff0088ce 0xff0185cd 0xff0084cc 0xff0082ca 0xff0180c9 0xff007fc6 0xff007dc5 0xff017bc4 0xff007ac3 0xff0078c1 0xff0176bf 0xff0074be 0xff0173bc 0xff0070ba 0xff006fb9 0xff006db8 0xff006bb7 0xff0169b5 0xff005bad 0xffd6e8f2 0xff9ec8e4 0xff1c4c92 0xffff171a 0xff1757a1 0xff0560af 0x094095e1 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x7b2e93d3 0xff0073c2 0xff82436b 0xffd5232f 0xff007cc8 0xffffffff 0xff3394cf 0xff0078c4 0xff017ec5 0xff007fc7 0xff0181ca 0xff0083cb 0xff0184cc 0xff0186ce 0xff0082cd 0xff77c0e3 0xffffffff 0xffe2f1f8 0xff57b6e3 0xff0894d8 0xff008cd5 0xff008fd7 0xff0093d8 0xff0095dc 0xff0098dd 0xff0098de 0xff0099de 0xff0099df 0xff0099de 0xff0098dd 0xff0098dd 0xff0096db 0xff0093d9 0xff0093d8 0xff0091d7 0xff008fd6 0xff008dd4 0xff008bd2 0xff008ad0 0xff0088cf 0xff0086cd 0xff0083cc 0xff0083cc 0xff0080c9 0xff007fc9 0xff007ec5 0xff007cc5 0xff007ac4 0xff0079c3 0xff0078c1 0xff0076bf 0xff0074bd 0xff0072bb 0xff0070ba 0xff006eb9 0xff006cb7 0xff006bb7 0xff0169b5 0xff0065b3 0xff1571b9 0xffffffff 0xff0a74c1 0xffb52942 0xff9d3151 0xff005db3 0x9b2679c2 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0xff0e76bf 0xff046eb7 0xfff3181e 0xff295998 0xff9ecfeb 0xffb4d8eb 0xff0070bf 0xff017bc4 0xff017dc5 0xff007fc7 0xff0080c9 0xff0083cb 0xff0084cc 0xff0086cd 0xff0188ce 0xff0081ce 0xff7ec4e7 0xffffffff 0xffffffff 0xffffffff 0xffedf7fc 0xffafdcf2 0xff8cceee 0xff77c7ec 0xff6ac2eb 0xff67c3ea 0xff60bfea 0xff5fbfec 0xff59bde9 0xff54bbe8 0xff55bae7 0xff4bb4e5 0xff49b3e4 0xff46b1e2 0xff3dace1 0xff40ace1 0xff37a7de 0xff33a4da 0xff33a3da 0xff2a9dd7 0xff2b9cd7 0xff2596d3 0xff2093d2 0xff2092d2 0xff178bcd 0xff158bcb 0xff1386c9 0xff0c80c6 0xff0d80c6 0xff057ac2 0xff0477c0 0xff0074bd 0xff0173bc 0xff0070ba 0xff006eb9 0xff006cb7 0xff006bb6 0xff0169b5 0xff0066b4 0xff005cae 0xff8db9da 0xffc6dfee 0xff0e4c98 0xfffa1a1c 0xff1c539e 0xff025cac 0x0884bcf0 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x573c96d5 0xff006fbf 0xff6d4975 0xffc6283c 0xff0078c4 0xffffffff 0xff1f88c8 0xff0077c1 0xff017bc4 0xff017dc5 0xff007ec6 0xff0080c9 0xff0082ca 0xff0084cc 0xff0085cd 0xff0187ce 0xff0089cf 0xff0086cf 0xff7ec5e7 0xff97d0ec 0xff95d1ee 0xff99d3ee 0xff9dd5f0 0xff9fd7f0 0xffa1d8f1 0xffa1d8f1 0xffa2d8f2 0xffa3d9f2 0xffa3d9f2 0xffa3d9f2 0xffa3d9f1 0xffa3d9f1 0xffa4daf2 0xffa4d9f1 0xffa2d7f0 0xff9fd5ed 0xff9fd5ef 0xff9cd2ed 0xff9bd1ec 0xff9ad0eb 0xff97ceea 0xff96cce9 0xff94cbe9 0xff92cae8 0xff91c9e7 0xff8ec6e5 0xff8dc5e5 0xff8cc3e3 0xff88c1e2 0xff88c1e1 0xff87bfe1 0xff6fb1d9 0xff0070ba 0xff0072bb 0xff0070ba 0xff006eb9 0xff006cb7 0xff006ab6 0xff0168b5 0xff0066b4 0xff0064b1 0xff0b69b4 0xffffffff 0xff0d71bb 0xffa92c48 0xff88375d 0xff005aae 0x6d2676c2 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0xcf1277bc 0xff0071c1 0xffd62432 0xff4c4d80 0xff7dbfe4 0xffc6e0f0 0xff0070be 0xff0079c2 0xff007ac3 0xff007cc4 0xff007ec6 0xff007fc7 0xff0181ca 0xff0083cb 0xff0084cc 0xff0086cd 0xff0089cf 0xff018ad0 0xff0088cf 0xff0088d0 0xff008ad3 0xff008bd4 0xff008cd5 0xff008ed6 0xff0090d7 0xff0091d7 0xff0091d8 0xff0092da 0xff0092da 0xff0092d8 0xff0091d8 0xff0091d9 0xff008fd6 0xff008ed6 0xff008cd5 0xff008bd4 0xff008ad3 0xff0088d0 0xff0086cf 0xff0085cd 0xff0083cc 0xff0081cb 0xff007fc9 0xff007ec9 0xff007cc7 0xff007ac4 0xff0078c3 0xff0077c2 0xff0075c1 0xff0073c0 0xff0071be 0xff0070bd 0xff0173bd 0xff0072bb 0xff006fba 0xff006db8 0xff016cb8 0xff006ab6 0xff0068b4 0xff0165b3 0xff0064b2 0xff0059ad 0xffa0c3e0 0xffa4cae6 0xff2e4386 0xffeb1c26 0xff0057a9 0xf1085dab 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x0c6eafe0 0xff006cba 0xff335d98 0xffef1a21 0xff026ab5 0xfff4fbfc 0xff3d96ce 0xff0074bf 0xff0078c1 0xff007ac3 0xff007cc4 0xff007ec5 0xff007fc6 0xff0080c9 0xff0082cb 0xff0084cc 0xff0085cd 0xff0188ce 0xff008acf 0xff008bd0 0xff008dd2 0xff008ed4 0xff008fd5 0xff0090d6 0xff0092d7 0xff0093d8 0xff0094d8 0xff0095d9 0xff0095d9 0xff0095d9 0xff0095d9 0xff0094d9 0xff0093d8 0xff0192d7 0xff0091d7 0xff0090d6 0xff008fd5 0xff008dd3 0xff008cd1 0xff008bd0 0xff0089cf 0xff0187ce 0xff0085cc 0xff0083cb 0xff0082ca 0xff0080c8 0xff007fc6 0xff017dc5 0xff007bc3 0xff0079c2 0xff0078c1 0xff0176bf 0xff0074be 0xff0173bc 0xff0071bb 0xff006fb9 0xff006db8 0xff006cb7 0xff006ab6 0xff0067b4 0xff0065b3 0xff0064b2 0xff005fb0 0xff2676b9 0xffffffff 0xff0763b1 0xffdc1f2b 0xff4e4580 0xff0053a7 0x2c5895d5 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x623291d4 0xff006cbd 0xff8a3e63 0xff983555 0xff3f9fd6 0xfffffffe 0xff0070bd 0xff0075bf 0xff0178c1 0xff0079c2 0xff007bc4 0xff017dc5 0xff007fc6 0xff0080c8 0xff0082ca 0xff0083cb 0xff0084cc 0xff0086cd 0xff0188ce 0xff008ad0 0xff0089d0 0xff0087d0 0xff0088d2 0xff0089d3 0xff008ad4 0xff008bd5 0xff008bd5 0xff008dd6 0xff008dd6 0xff008dd6 0xff008dd6 0xff008cd6 0xff008bd5 0xff008ad4 0xff008ad3 0xff0089d3 0xff0088d2 0xff0086ce 0xff0085cf 0xff0083cc 0xff0080cb 0xff0080ca 0xff007dc9 0xff007dc8 0xff007ac7 0xff0078c5 0xff0077c2 0xff0075c1 0xff0073c0 0xff0072bf 0xff0074c0 0xff0175be 0xff0074bd 0xff0173bc 0xff0071bb 0xff006eb9 0xff006db8 0xff006bb6 0xff0069b5 0xff0067b4 0xff0065b3 0xff0064b2 0xff0162b1 0xff0055a8 0xffebf3f7 0xff5da2d3 0xff7d335f 0xffaf2c45 0xff0057af 0x802f77c2 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0xb72989d0 0xff006fc2 0xfff7181c 0xff404c86 0xffa1d0ea 0xff98c6e3 0xff006dba 0xff0075bf 0xff0078c1 0xff0079c2 0xff007ac3 0xff017cc4 0xff007ec6 0xff007fc7 0xff0081ca 0xff0083cb 0xff0184cc 0xff0085cc 0xff0086cd 0xff0086d0 0xff41a7db 0xffc5e5f3 0xffc0e2f3 0xffbfe2f4 0xffbfe3f3 0xffbfe3f3 0xffbfe3f3 0xffbfe3f3 0xffbfe4f3 0xffbfe4f3 0xffbfe4f3 0xffbfe3f3 0xffbfe3f3 0xffbfe3f3 0xffbfe2f4 0xffbfe2f4 0xffbfe2f3 0xffbfe3f2 0xffbfe2f2 0xffbfe1f2 0xffbfe1f2 0xffbfe0f3 0xffbfdff1 0xffbfdff2 0xffbfdef1 0xffbfddf0 0xffbfdef0 0xffbfdeef 0xffbfddef 0xffc7e0f0 0xff52a3d3 0xff0072be 0xff0173bd 0xff0072bb 0xff0070ba 0xff006eb9 0xff016db8 0xff006bb6 0xff0168b5 0xff0066b4 0xff0065b3 0xff0063b1 0xff0061b0 0xff0059ac 0xff6fa4d1 0xffc0daed 0xff214289 0xffff1412 0xff0057aa 0xdd2071c0 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0xff096fba 0xff1862a6 0xffff1314 0xff0460ac 0xffeef7fa 0xff3a91ca 0xff0070ba 0xff0075bf 0xff0177c1 0xff0078c2 0xff007ac3 0xff007bc4 0xff017dc5 0xff007fc6 0xff0080c8 0xff0081ca 0xff0083cb 0xff0084cc 0xff0085cd 0xff0187ce 0xff0087ce 0xff0084ce 0xff0085cf 0xff0086ce 0xff0087d0 0xff0088d2 0xff0089d2 0xff0089d3 0xff0089d3 0xff0089d3 0xff0089d3 0xff0089d3 0xff0088d2 0xff0087d0 0xff0087d0 0xff0086cf 0xff0085ce 0xff0084cd 0xff0082cb 0xff007fca 0xff007fc9 0xff007eca 0xff007dc7 0xff007ac8 0xff0078c4 0xff0077c2 0xff0075c1 0xff0074c1 0xff0073bf 0xff0071be 0xff0073be 0xff0174bd 0xff0173bc 0xff0071bb 0xff006eb9 0xff006db8 0xff006cb7 0xff006ab5 0xff0067b4 0xff0066b3 0xff0064b2 0xff0162b1 0xff0060b0 0xff005dad 0xff2271b7 0xffffffff 0xff0559a8 0xffea1b25 0xff37498a 0xff0051a6 0x03acd3ef 0x00000000 0x00000000 0x00000000 0x00000000 0x1d4e97cf 0xff0065b6 0xff574d80 0xffc4263b 0xff2188ca 0xfff7fafb 0xff0775bd 0xff0071bb 0xff0074be 0xff0075bf 0xff0078c1 0xff0079c2 0xff007ac3 0xff007cc4 0xff017ec5 0xff007fc7 0xff0080c9 0xff0082ca 0xff0083cb 0xff0084cc 0xff0086cd 0xff0087ce 0xff0089cf 0xff0088cf 0xff0087ce 0xff0088cf 0xff0088d1 0xff0089d0 0xff0089d0 0xff0089d0 0xff0089d2 0xff0089d0 0xff0089d0 0xff0089d1 0xff0088cf 0xff0087ce 0xff0087ce 0xff0085cd 0xff0084cc 0xff0083cb 0xff0081cb 0xff0080ca 0xff007fc9 0xff007dc7 0xff007ac6 0xff007bc5 0xff0079c3 0xff0077c2 0xff0076c1 0xff0075c1 0xff0177c1 0xff0075be 0xff0174bd 0xff0172bc 0xff0070ba 0xff006eb9 0xff006db8 0xff006bb7 0xff0069b5 0xff0067b4 0xff0065b3 0xff0064b2 0xff0061b0 0xff005faf 0xff005dae 0xff0059ac 0xffe3eff5 0xff3989c8 0xffa72946 0xff733867 0xff0054a9 0x393a7ab9 0x00000000 0x00000000 0x00000000 0x00000000 0x553787c1 0xff0068ba 0xff8d3c60 0xff8a375a 0xff5aa9da 0xffc4deee 0xff0068b7 0xff0072bb 0xff0173bc 0xff0074bd 0xff0077c0 0xff0078c1 0xff007ac3 0xff007bc4 0xff007dc4 0xff007ec5 0xff007fc6 0xff0180c9 0xff0082ca 0xff0083cb 0xff0084cc 0xff0185cd 0xff0084cd 0xff43a6da 0xff73bde5 0xff70bee5 0xff6ebee5 0xff70bee6 0xff70bee5 0xff70bee6 0xff70bee6 0xff70bee6 0xff70bee6 0xff70bee5 0xff71bde5 0xff6fbde4 0xff70bce4 0xff70bbe4 0xff70bbe3 0xff6ebae3 0xff6eb9e3 0xff70b9e2 0xff70b8e0 0xff6eb7df 0xff70b6df 0xff70b5dd 0xff70b6dd 0xff70b5de 0xff73b4dd 0xff4b9dd2 0xff0073bf 0xff0074bd 0xff0173bc 0xff0071bb 0xff0070ba 0xff006eb9 0xff006cb8 0xff006cb7 0xff006ab5 0xff0066b4 0xff0066b4 0xff0063b1 0xff0061b0 0xff005faf 0xff015eae 0xff0054a9 0xffa7c6e0 0xff7ab0da 0xff6e3362 0xffb02a45 0xff0055ae 0x7b2c70b3 0x00000000 0x00000000 0x00000000 0x00000000 0x902c7ebe 0xff006abb 0xffc8283c 0xff594377 0xff8ec5e5 0xff91c1e0 0xff0068b7 0xff0071bb 0xff0173bc 0xff0174bd 0xff0076be 0xff0177c1 0xff0079c2 0xff007ac3 0xff007cc4 0xff017dc5 0xff007fc6 0xff007fc7 0xff0180c9 0xff0182ca 0xff0083cb 0xff0084cc 0xff0084cd 0xff2696d3 0xff50acdd 0xff4cacdd 0xff4eacdd 0xff4dacdd 0xff4dabdd 0xff4dadde 0xff4eadde 0xff4dacde 0xff4dacdc 0xff4dacdd 0xff4cacdd 0xff4eabdd 0xff4eabdd 0xff4eaadc 0xff4da9dc 0xff4da9db 0xff4da8db 0xff4ea7da 0xff4ea6d9 0xff4ea5d9 0xff4ea6d8 0xff4da3d6 0xff4ea4d5 0xff4da2d6 0xff4fa2d4 0xff2b8dca 0xff0073bd 0xff0173bd 0xff0171ba 0xff016fba 0xff016bb7 0xff016ab5 0xff0167b5 0xff0165b2 0xff0162b0 0xff0160af 0xff015eae 0xff035ead 0xff045bab 0xff045baa 0xff025aaa 0xff0053a7 0xff6e9cc7 0xffa2c1db 0xff323f83 0xffeb1c24 0xff0056af 0xb62369b0 0x00000000 0x00000000 0x00000000 0x00000000 0xb4146eb8 0xff006abd 0xffff161a 0xff1e539a 0xffbbdbed 0xff66a7d5 0xff0069b7 0xff0070ba 0xff0172bb 0xff0173bc 0xff0074bd 0xff0076c0 0xff0178c1 0xff0079c2 0xff017ac3 0xff007bc4 0xff007dc5 0xff017ec6 0xff007fc7 0xff0080c9 0xff0081ca 0xff0083cb 0xff0084cb 0xff0084cc 0xff0083cc 0xff007eca 0xff007fc9 0xff007ec9 0xff0080cb 0xff0080ca 0xff007fca 0xff0080ca 0xff007ec9 0xff007fc9 0xff007fca 0xff007dc8 0xff007cc8 0xff007bc7 0xff007cc6 0xff0079c5 0xff0078c4 0xff0076c2 0xff0073c0 0xff0071bf 0xff006ebc 0xff006cba 0xff0069b9 0xff0066b7 0xff0069b8 0xff006ab7 0xff0068b4 0xff0065b2 0xff0063b1 0xff0161b0 0xff005fae 0xff005dac 0xff005baa 0xff0059a9 0xff0057a7 0xff0055a5 0xff0253a4 0xff0750a5 0xff0a4ea2 0xff0b4da2 0xff0b4da2 0xff074ba1 0xff3365a1 0xff8d98a6 0xff0148a3 0xffdd221a 0xff024fa4 0xd71d5cab 0x00000000 0x00000000 0x00000000 0x00000000 0xf12a7cbe 0xff0066b6 0xffff100c 0xff005fb2 0xffdfedf6 0xff4492c9 0xff006bb8 0xff006fb9 0xff0071ba 0xff0072bb 0xff0173bd 0xff0074be 0xff0177c0 0xff0078c1 0xff0079c2 0xff007ac3 0xff007cc4 0xff007dc5 0xff017ec6 0xff007fc6 0xff007fc8 0xff0181ca 0xff0182ca 0xff0083cb 0xff0384ca 0xffa5d3eb 0xffaad5ee 0xffa8d6ed 0xffa9d5ee 0xffa9d4ee 0xffa8d6ef 0xffa9d5ef 0xffa8d5ee 0xffa8d5ee 0xffa9d5ee 0xffa8d6ee 0xffa8d5ee 0xffa8d4ed 0xffa8d4ec 0xffa8d2eb 0xffa8d0ea 0xffa8cfe8 0xffa7cee8 0xffa8cee7 0xffa7cfe7 0xffa7cde7 0xffa7cee7 0xffa7cce3 0xff197abe 0xff0069b6 0xff006ab6 0xff0067b4 0xff0065b3 0xff0064b2 0xff0162b0 0xff005faf 0xff005eac 0xff005cab 0xff0059aa 0xff0057a8 0xff0055a6 0xff0353a5 0xff0750a4 0xff0a4ea3 0xff0a4ea3 0xff074da3 0xff225ca6 0xffa8aaaf 0xff004dac 0xffd42322 0xff1a4997 0xee195cab 0x00000000 0x00000000 0x00000000 0x00000000 0xff116cb5 0xff0f5fa8 0xffff1312 0xff0063bc 0xfff8fbfb 0xff2983c2 0xff006bb7 0xff006eb9 0xff006fba 0xff0071bb 0xff0072bb 0xff0174bd 0xff0075be 0xff0077c0 0xff0078c1 0xff0079c2 0xff007ac3 0xff007bc4 0xff007dc4 0xff007ec5 0xff007fc6 0xff017fc7 0xff0080c8 0xff0081c9 0xff0081ca 0xff138bce 0xff118bce 0xff128cd1 0xff128cd1 0xff128dd0 0xff118acc 0xff1187cb 0xff1184c8 0xff1182c6 0xff1281c6 0xff1182c6 0xff1182c7 0xff1182c6 0xff1182c6 0xff1181c6 0xff1180c5 0xff1180c4 0xff117fc4 0xff117fc3 0xff127ec2 0xff127dc2 0xff137bc0 0xff147bc0 0xff006db8 0xff006db8 0xff006cb7 0xff0069b5 0xff0067b4 0xff0065b3 0xff0064b2 0xff0061b0 0xff005faf 0xff005eaa 0xff005bab 0xff0058a9 0xff0057a7 0xff0154a6 0xff0551a5 0xff094fa4 0xff0a4ea3 0xff084da3 0xff1655a3 0xffadafb1 0xff0255ab 0xffc3272b 0xff2c468d 0xff1559ab 0x00000000 0x00000000 0x00000000 0x00000000 0xff0160b1 0xff1f5b9e 0xfff8171c 0xff006abe 0xffffffff 0xff1978bc 0xff006ab6 0xff016db8 0xff006eb9 0xff006fba 0xff0071bb 0xff0173bc 0xff0174bd 0xff0075be 0xff0076c1 0xff0178c1 0xff0079c2 0xff007ac3 0xff017bc4 0xff007cc4 0xff017dc5 0xff007ec6 0xff007fc6 0xff007fc9 0xff0180c9 0xff007dc6 0xff248ece 0xff248ecb 0xff258cca 0xff248ac8 0xff248aca 0xff248bcb 0xff238dcb 0xff238dcd 0xff238dcd 0xff238ecd 0xff238ecd 0xff238ecd 0xff238dcd 0xff248dcd 0xff248ccc 0xff248ccb 0xff248bcb 0xff248bcb 0xff248aca 0xff2489c7 0xff2386c7 0xff0070bb 0xff0171bb 0xff006fba 0xff006db8 0xff006cb7 0xff006ab6 0xff0067b4 0xff0065b3 0xff0063b2 0xff0060b0 0xff015fae 0xff005dad 0xff005aab 0xff0058a8 0xff0056a6 0xff0253a5 0xff0750a5 0xff0a4ea3 0xff094da3 0xff1253a4 0xffaaaeb5 0xff0e5aac 0xffb82732 0xff394486 0xff074fa7 0x00000000 0x00000000 0x00000000 0x00000000 0xff005fb0 0xff27579b 0xfff11a21 0xff006ebf 0xfffcfdfd 0xff1474bb 0xff0068b5 0xff016cb7 0xff016db8 0xff006eb9 0xff0070ba 0xff0171bb 0xff0173bc 0xff0074bd 0xff0075be 0xff0076c0 0xff0078c1 0xff0079c2 0xff007ac3 0xff007cc5 0xff007cc5 0xff017dc5 0xff017ac2 0xff0177c0 0xff0174bd 0xff0070bd 0xff69add7 0xff93c5e5 0xff91c5e5 0xff91c5e6 0xff91c6e6 0xff91c6e6 0xff91c7e7 0xff91c7e7 0xff91c8e7 0xff91c8e7 0xff91c8e7 0xff91c8e7 0xff91c8e7 0xff90c7e7 0xff91c7e7 0xff91c7e6 0xff91c6e6 0xff91c6e6 0xff91c5e5 0xff94c5e5 0xff6fb3da 0xff0070bb 0xff0173bc 0xff0071bb 0xff006fb9 0xff006db8 0xff006cb7 0xff0068b5 0xff0066b4 0xff0064b2 0xff0162b1 0xff0060af 0xff005eae 0xff005cad 0xff0059aa 0xff0157a7 0xff0154a6 0xff0451a5 0xff084fa4 0xff094da3 0xff0f53a4 0xffadb1b7 0xff1560ad 0xffb12838 0xff3d4383 0xff054fa6 0x00000000 0x00000000 0x00000000 0x00000000 0xff005eaf 0xff25579a 0xfff01a20 0xff006bc0 0xfffcfdfd 0xff1473ba 0xff0067b4 0xff006bb7 0xff006cb7 0xff006db8 0xff006fb9 0xff0070ba 0xff0072bb 0xff0173bc 0xff0174bd 0xff0075bf 0xff0076c1 0xff0179c2 0xff0177c1 0xff0173be 0xff006fba 0xff006eb8 0xff0170ba 0xff0173bb 0xff0075bf 0xff0176c0 0xff0074bf 0xff0074c0 0xff0074c1 0xff0075c2 0xff0076c3 0xff0078c4 0xff0079c5 0xff0078c5 0xff007ac6 0xff007bc6 0xff007bc6 0xff007bc6 0xff0078c6 0xff0079c6 0xff0079c5 0xff0077c3 0xff0077c3 0xff0075c2 0xff0074c1 0xff0073c0 0xff0074c0 0xff0176c0 0xff0074be 0xff0073bc 0xff0071ba 0xff006eb9 0xff006db8 0xff006bb6 0xff0168b5 0xff0066b4 0xff0064b2 0xff0061b0 0xff005faf 0xff005dad 0xff005bab 0xff0058a8 0xff0056a6 0xff0253a5 0xff0750a4 0xff094da3 0xff0f51a3 0xffb1b5bb 0xff1560ae 0xffb42838 0xff3e4483 0xff054fa6 0x00000000 0x00000000 0x00000000 0x00000000 0xff005dad 0xff1f579c 0xfff9171d 0xff0067ba 0xfffffffe 0xff1a75ba 0xff0066b3 0xff006ab5 0xff006cb7 0xff006cb7 0xff006db8 0xff006fb9 0xff0070ba 0xff0072bc 0xff0073bc 0xff0171bc 0xff016eb9 0xff0169b5 0xff0069b5 0xff006bb6 0xff006eb9 0xff0070ba 0xff0173bc 0xff0074bf 0xff0076c0 0xff0078c1 0xff0076c0 0xff63aeda 0xffc3dff0 0xffbbddf0 0xffb9def0 0xffbbddf1 0xffbbdef1 0xffbbdef1 0xffbbdef1 0xffbbdef1 0xffbbdef1 0xffbbdef1 0xffbcdef1 0xffbbdef1 0xffbbdef1 0xffbbddf1 0xffbbdcf0 0xffbbdcf0 0xffbfe0f0 0xff83bee2 0xff0076c0 0xff0078c1 0xff0076c0 0xff0074be 0xff0172bc 0xff0070ba 0xff006eb9 0xff006cb7 0xff006ab6 0xff0067b4 0xff0065b3 0xff0063b1 0xff0060ae 0xff015ead 0xff005cac 0xff0058a9 0xff0057a7 0xff0154a6 0xff0551a5 0xff084ea4 0xff1253a4 0xffb4b9be 0xff0c5bad 0xffbe2631 0xff394486 0xff0751a7 0x00000000 0x00000000 0x00000000 0x00000000 0xff1168b2 0xff0f5aa6 0xffff1312 0xff005eb8 0xfff7f9fa 0xff2a7fc1 0xff0063b3 0xff0168b5 0xff0069b5 0xff006bb6 0xff006db7 0xff0170b9 0xff016db8 0xff0167b4 0xff0161b1 0xff0063b1 0xff0065b4 0xff0169b5 0xff006cb7 0xff006eb8 0xff0070ba 0xff0072bb 0xff0074be 0xff0076c0 0xff0078c1 0xff007ac3 0xff017cc4 0xff0079c3 0xff1288ca 0xff1f8ecd 0xff1d90d0 0xff1d91d0 0xff1d92d2 0xff1d93d2 0xff1d94d3 0xff1f94d3 0xff1f94d3 0xff1f94d3 0xff1d94d3 0xff1d93d2 0xff1d92d2 0xff1f92d0 0xff1f90cf 0xff1e8fcf 0xff1589ca 0xff0078c5 0xff017bc4 0xff007ac3 0xff0078c1 0xff0076c0 0xff0173be 0xff0172bb 0xff0070ba 0xff016db8 0xff006cb7 0xff0069b5 0xff0066b4 0xff0064b2 0xff0061b0 0xff005faf 0xff005dad 0xff005aab 0xff0058a8 0xff0055a6 0xff0352a5 0xff064ea4 0xff1755a4 0xffc1c2c5 0xff0054aa 0xffce242b 0xff2b468d 0xff155aab 0x00000000 0x00000000 0x00000000 0x00000000 0xf12f7bbc 0xff005eb2 0xffff110d 0xff0056ad 0xffddebf4 0xff458ec5 0xff0061b1 0xff0066b4 0xff0169b6 0xff0168b5 0xff0162b1 0xff015cac 0xff015dab 0xff005faf 0xff0062b1 0xff0065b3 0xff0167b4 0xff006ab6 0xff006db8 0xff006fb9 0xff0071ba 0xff0073bd 0xff0075bf 0xff0078c1 0xff0079c2 0xff017cc4 0xff017ec5 0xff007cc7 0xff43a1d6 0xff90c9e7 0xff88c6e7 0xff88c7e8 0xff86c7e7 0xff86c8e7 0xff88c8e7 0xff88c8e7 0xff88c8e7 0xff88c8e7 0xff88c8e7 0xff86c8e7 0xff88c7e7 0xff88c5e8 0xff88c6e7 0xff90c9e7 0xff48a4d6 0xff007bc7 0xff007ec5 0xff007bc4 0xff007ac2 0xff0078c1 0xff0075bf 0xff0173bc 0xff0070ba 0xff006fb9 0xff016db8 0xff016ab6 0xff0067b4 0xff0065b3 0xff0062b1 0xff0060af 0xff015ead 0xff005bac 0xff0058a9 0xff0056a7 0xff0253a5 0xff034ea3 0xff2660a7 0xffc0c4c7 0xff004bab 0xffe11f1e 0xff1a4a98 0xee1c5dab 0x00000000 0x00000000 0x00000000 0x00000000 0xb41768b0 0xff0061b8 0xfffd171b 0xff1f4b90 0xffbad9ed 0xff6aa5d2 0xff005fb0 0xff045fae 0xff015aa9 0xff0156a8 0xff0158ab 0xff005dac 0xff015fad 0xff0061b0 0xff0064b2 0xff0166b3 0xff0168b5 0xff006bb7 0xff006db8 0xff0070ba 0xff0172bc 0xff0074be 0xff0077c1 0xff0079c2 0xff007bc4 0xff017dc5 0xff007fc7 0xff0081ca 0xff007dc9 0xff55addb 0xff7fc2e5 0xff7cc1e6 0xff7cc2e6 0xff7cc2e7 0xff7cc3e7 0xff7cc3e7 0xff7cc3e7 0xff7cc3e7 0xff7cc3e7 0xff7cc2e7 0xff7cc1e6 0xff7cc1e6 0xff7ec1e5 0xff5aafdc 0xff007dc8 0xff0081c9 0xff017fc7 0xff007dc5 0xff007bc4 0xff0079c2 0xff0077c0 0xff0074be 0xff0072bc 0xff0070ba 0xff006db8 0xff006bb7 0xff0068b5 0xff0065b3 0xff0063b2 0xff0061b0 0xff015ead 0xff005cac 0xff0059aa 0xff0057a7 0xff0154a6 0xff004ea4 0xff4072ae 0xffacb9c6 0xff0246a0 0xffef1d17 0xff0150a5 0xd21a59aa 0x00000000 0x00000000 0x00000000 0x00000000 0x903079ba 0xff005eb2 0xffc5273c 0xff5c3c71 0xff80b2d6 0xff7da0c2 0xff004ba2 0xff0352a4 0xff0054a6 0xff0158a6 0xff005aab 0xff005dac 0xff0060af 0xff0062b1 0xff0064b2 0xff0067b4 0xff0069b6 0xff016db8 0xff006eb9 0xff0071ba 0xff0173bd 0xff0075c0 0xff0078c1 0xff007ac3 0xff017cc4 0xff007ec7 0xff0080c8 0xff0083cb 0xff0084cc 0xff1f94d3 0xff309ed9 0xff299ed9 0xff299fda 0xff29a0db 0xff29a0db 0xff29a1dc 0xff29a1dc 0xff29a1dc 0xff29a0db 0xff29a0db 0xff299fda 0xff299ed9 0xff2d9ed8 0xff2396d4 0xff0084cc 0xff0083cb 0xff0080c8 0xff007fc6 0xff017cc4 0xff007ac3 0xff0078c1 0xff0075c0 0xff0173bd 0xff0071bb 0xff006eb9 0xff006cb7 0xff0069b6 0xff0067b4 0xff0065b3 0xff0162b1 0xff015faf 0xff005dab 0xff005aab 0xff0158a8 0xff0055a6 0xff004da3 0xff638ab8 0xff8aa6c4 0xff343e7f 0xffd2232b 0xff004faa 0xb52e69b0 0x00000000 0x00000000 0x00000000 0x00000000 0x523a7db9 0xff005ab0 0xff83395f 0xff7f3157 0xff396fa8 0xff8090a5 0xff014aa4 0xff0353a5 0xff0055a6 0xff0058a9 0xff005bac 0xff005ead 0xff0060b0 0xff0163b1 0xff0065b3 0xff0068b5 0xff006bb6 0xff006db8 0xff006fb9 0xff0072bb 0xff0074bd 0xff0076c0 0xff0079c2 0xff007bc4 0xff017dc6 0xff007fc8 0xff0082ca 0xff0084cc 0xff0186cd 0xff0085cd 0xff82c5e7 0xffa9d9f0 0xffa5d8f0 0xffa5d7f1 0xffa5d7f1 0xffa7d9f1 0xffa6d9f1 0xffa7d9f1 0xffa5d7f1 0xffa5d8f1 0xffa5d8f0 0xffa8d8f1 0xff9bd0eb 0xff0084ce 0xff0186cd 0xff0084cc 0xff0082ca 0xff0080c7 0xff017ec5 0xff007bc4 0xff0079c2 0xff0177c1 0xff0174bd 0xff0172bb 0xff006fba 0xff006db8 0xff006ab6 0xff0068b4 0xff0065b3 0xff0062b1 0xff005faf 0xff015dac 0xff005bac 0xff0058a9 0xff0056a6 0xff004ba2 0xff8ca7c4 0xff6592bf 0xff693364 0xff9b2f49 0xff004ea7 0x7a366fb3 0x00000000 0x00000000 0x00000000 0x00000000 0x1b598fc4 0xff004ba4 0xff46417a 0xff9d2d3f 0xff1b5ca8 0xffa2a6ab 0xff0c52a3 0xff0052a5 0xff0056a7 0xff0058aa 0xff005cac 0xff015ead 0xff0061b0 0xff0063b2 0xff0065b3 0xff0069b5 0xff006bb7 0xff006db8 0xff0070ba 0xff0173bc 0xff0075bf 0xff0078c1 0xff007ac3 0xff017cc5 0xff007ec7 0xff0181c9 0xff0083cb 0xff0085cd 0xff0088ce 0xff008ad0 0xff088fd3 0xff8accea 0xff87caea 0xff88cbeb 0xff87cbed 0xff87cceb 0xff87cceb 0xff87cceb 0xff87cbed 0xff88caeb 0xff87caea 0xff8ccdea 0xff0790d2 0xff0089d0 0xff0188ce 0xff0085cd 0xff0083cb 0xff0181c9 0xff007ec6 0xff017cc5 0xff007ac3 0xff0077c1 0xff0075bf 0xff0173bc 0xff0070ba 0xff006eb9 0xff006cb7 0xff0069b5 0xff0065b3 0xff0063b1 0xff0060b0 0xff015ead 0xff005cac 0xff0058aa 0xff0055a5 0xff0052a5 0xffbec8d0 0xff3375b7 0xff9b2b47 0xff683a69 0xff004aa3 0x38447ab6 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0xff1557a9 0xff174997 0xffcf2321 0xff104599 0xff9fa6af 0xff2c67a7 0xff0052a5 0xff0056a7 0xff0059aa 0xff015cac 0xff015eae 0xff0061b0 0xff0064b2 0xff0066b3 0xff0069b5 0xff006cb7 0xff006eb9 0xff0071bb 0xff0073bc 0xff0076c0 0xff0079c2 0xff017bc3 0xff007dc6 0xff007fc7 0xff0182ca 0xff0084cc 0xff0087ce 0xff0089cf 0xff018cd1 0xff018dd3 0xff2ca2dc 0xff40ade1 0xff3eafe1 0xff3eaee2 0xff3fb0e2 0xff3fb0e2 0xff3fb0e2 0xff3eaee2 0xff3eade1 0xff40aee1 0xff2ba2db 0xff018dd3 0xff018cd1 0xff0089cf 0xff0087ce 0xff0084cc 0xff0182ca 0xff007fc7 0xff007dc6 0xff017bc3 0xff0078c2 0xff0075c0 0xff0073bd 0xff0171bb 0xff006eb9 0xff006cb7 0xff0069b5 0xff0166b4 0xff0064b2 0xff0061b0 0xff005eae 0xff005cac 0xff0059aa 0xff0054a6 0xff1f66ac 0xffd8d9d9 0xff0d4c9f 0xffd62027 0xff354488 0xff054fa3 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0xad2b6dbc 0xff0050ab 0xffbe282c 0xff3d3d79 0xff6d8cb1 0xff6e8cad 0xff004fa5 0xff0057a7 0xff0059aa 0xff005dac 0xff015fae 0xff0161b1 0xff0064b2 0xff0066b4 0xff006ab6 0xff006cb7 0xff006fb9 0xff0072bb 0xff0073bd 0xff0076c0 0xff0079c2 0xff017bc4 0xff017ec5 0xff0080c8 0xff0083cb 0xff0085cc 0xff0188ce 0xff008bd0 0xff008dd2 0xff008ed5 0xff28a1db 0xff9fd8f1 0xff96d4f0 0xff97d4f1 0xff97d5f2 0xff97d5f1 0xff97d5f1 0xff97d4f1 0xff96d5f0 0xff9fd6f1 0xff29a2db 0xff008dd5 0xff008dd3 0xff008bd0 0xff0187ce 0xff0085cc 0xff0083cb 0xff0080c9 0xff007ec5 0xff007bc4 0xff0079c2 0xff0076c0 0xff0073bd 0xff0071bb 0xff006fb9 0xff006db8 0xff0069b5 0xff0066b4 0xff0064b2 0xff0061b0 0xff015eae 0xff015cac 0xff0059aa 0xff0052a6 0xff6592be 0xffa3bbd2 0xff293b84 0xfff01d1a 0xff004ea6 0xd82a6cba 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x593370bd 0xff004da7 0xff703a60 0xff833151 0xff2d6caf 0xffb8b8b8 0xff0052a5 0xff0057a8 0xff0059aa 0xff005dac 0xff015faf 0xff0162b0 0xff0165b3 0xff0167b4 0xff016ab6 0xff006db8 0xff006fb9 0xff0072bb 0xff0074bd 0xff0177c1 0xff007ac3 0xff017cc4 0xff017ec6 0xff0080c9 0xff0083cb 0xff0086cd 0xff0089cf 0xff008cd1 0xff008ed4 0xff0090d6 0xff008fd7 0xff69bee8 0xffa0d8f1 0xff9cd7f2 0xff9cd7f3 0xff9cd8f3 0xff9cd7f2 0xff9cd7f2 0xffa0d8f1 0xff69bfe8 0xff008ed7 0xff0190d6 0xff008ed4 0xff008cd1 0xff0089cf 0xff0086cd 0xff0083cb 0xff0080c9 0xff007ec6 0xff007cc4 0xff0079c2 0xff0177c1 0xff0174be 0xff0072bb 0xff006fba 0xff006db8 0xff016ab6 0xff0167b4 0xff0064b2 0xff0062b1 0xff015faf 0xff005cab 0xff0059a9 0xff004fa4 0xffd3d9df 0xff508ac2 0xff78315c 0xff9c2e4c 0xff004fa8 0x74276ab9 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x0375a7e5 0xff064ea3 0xff2c478c 0xffc22629 0xff0b489c 0xffadb3bb 0xff316fac 0xff0056a7 0xff005aaa 0xff005dac 0xff015faf 0xff0162b0 0xff0065b3 0xff0167b4 0xff006ab6 0xff006db8 0xff006fba 0xff0172bb 0xff0074be 0xff0177c1 0xff007ac3 0xff017cc5 0xff007fc6 0xff0081c9 0xff0084cc 0xff0186cd 0xff0089cf 0xff008cd1 0xff008fd5 0xff0191d6 0xff0093d9 0xff0091d8 0xffb6e3f4 0xffacdff5 0xfface0f4 0xffaddff4 0xffade0f4 0xffacdff5 0xffb5e2f3 0xff119cdc 0xff0093d9 0xff0191d6 0xff018fd5 0xff018cd1 0xff0089cf 0xff0186cd 0xff0083cc 0xff0081c9 0xff007ec6 0xff007cc4 0xff007ac3 0xff0177c1 0xff0074be 0xff0072bb 0xff006fba 0xff006db8 0xff016ab6 0xff0167b4 0xff0064b2 0xff0062b1 0xff015faf 0xff005cac 0xff0058a9 0xff256db0 0xffe7e7e5 0xff0854a6 0xffce222e 0xff49417d 0xff004ba4 0x1d4880c3 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0xc2296abb 0xff0050a8 0xffac2c3b 0xff4a3b75 0xff5786b5 0xff98a9ba 0xff0051a6 0xff005aab 0xff005dac 0xff015fae 0xff0162b1 0xff0065b3 0xff0067b4 0xff006bb6 0xff006db8 0xff006fb9 0xff0172bb 0xff0074be 0xff0177c1 0xff007ac3 0xff017cc5 0xff007fc6 0xff0081ca 0xff0084cc 0xff0186cd 0xff0089cf 0xff008cd1 0xff008fd5 0xff0191d7 0xff0093d8 0xff0093db 0xff45b5e5 0xff8ed3f1 0xff86d1f1 0xff86d2f2 0xff86d1f1 0xff8ed3f1 0xff45b5e5 0xff0093d9 0xff0194d8 0xff0191d7 0xff008fd5 0xff008cd1 0xff018acf 0xff0186ce 0xff0084cc 0xff0081ca 0xff007ec6 0xff007cc5 0xff007ac3 0xff0177c1 0xff0074be 0xff0172bb 0xff006fba 0xff006db8 0xff016ab6 0xff0067b4 0xff0064b2 0xff0062b0 0xff015faf 0xff005dad 0xff0053a9 0xff98b5d1 0xff8fb3d4 0xff333c81 0xffd6212a 0xff044ea5 0xec1355a6 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x493575c1 0xff004ca3 0xff593d70 0xffa92c3d 0xff0052a8 0xffc7c6c4 0xff1d67ac 0xff0058ac 0xff005dab 0xff015fae 0xff0062b1 0xff0065b3 0xff0167b4 0xff016ab6 0xff006db8 0xff006fb9 0xff0072bb 0xff0074bd 0xff0074c0 0xff007ac3 0xff007cc4 0xff007ec8 0xff0081ca 0xff0084cc 0xff0186cd 0xff0089cf 0xff008cd1 0xff008fd5 0xff0091d7 0xff0094d8 0xff0196da 0xff0093dc 0xff8fd2ed 0xff93d5f1 0xff92d6f2 0xff93d7f1 0xff8ed1ef 0xff0093db 0xff0196da 0xff0093d8 0xff0190d6 0xff008fd5 0xff008cd1 0xff0089cf 0xff0086cd 0xff0084cc 0xff0081c9 0xff007ec6 0xff017cc4 0xff0079c3 0xff0177c1 0xff0074bd 0xff0172bb 0xff006fba 0xff016db8 0xff016ab6 0xff0067b4 0xff0064b2 0xff0062af 0xff015fae 0xff005cab 0xff0e61ac 0xfff9f4f0 0xff0762b0 0xffa32b46 0xff7e355f 0xff004fa6 0x672c6ebb 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0xff0a51a5 0xff0a4da2 0xffc9242a 0xff2b4186 0xff729abc 0xff93aac1 0xff0051a7 0xff005cab 0xff015fae 0xff0062b1 0xff0065b3 0xff0167b4 0xff016ab6 0xff006db8 0xff006fb9 0xff0172bc 0xff006eba 0xff4198ce 0xff006fbc 0xff017cc4 0xff017ec6 0xff0181c9 0xff0083cc 0xff0086cd 0xff0188cf 0xff008cd1 0xff008ed4 0xff0090d6 0xff0093d8 0xff0095d9 0xff0095d9 0xff4bb5e6 0xffaadff5 0xffa2dbf3 0xffabdef3 0xff4ab6e9 0xff0095d9 0xff0095d9 0xff0093d8 0xff0190d6 0xff008ed3 0xff008bd0 0xff0088cf 0xff0186cd 0xff0183cb 0xff0080c9 0xff017ec5 0xff0077c2 0xff238cc9 0xff006dbc 0xff006ebb 0xff0070ba 0xff006fba 0xff006db8 0xff016ab6 0xff0167b4 0xff0064b3 0xff0062b0 0xff015fae 0xff0054a8 0xff8eb2d3 0xffb0cbe0 0xff164290 0xffeb1d20 0xff1c4998 0xff0e53a5 0x0591bff4 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x723373c0 0xff004ea7 0xff6a3966 0xffba2833 0xff0054ac 0xffd4d2cd 0xff3073b2 0xff0059aa 0xff015fae 0xff0061b0 0xff0064b2 0xff0066b3 0xff0069b6 0xff006cb8 0xff006fb9 0xff006bb8 0xff4f9dd2 0xffd2e8f2 0xffc1deef 0xff0076c1 0xff007dc5 0xff0180c9 0xff0083cb 0xff0085cc 0xff0188ce 0xff008bd0 0xff008dd3 0xff0090d6 0xff0191d7 0xff0094d8 0xff0196da 0xff0092d9 0xff97d6f2 0xff9fd8f3 0xff96d6f1 0xff0091d9 0xff0196da 0xff0094d8 0xff0191d7 0xff008fd5 0xff008dd2 0xff008bd0 0xff0188ce 0xff0085cc 0xff0082cb 0xff0080c8 0xff007ac4 0xff65afdb 0xffcde5f0 0xffd3e8f3 0xff94c5e1 0xff2183c4 0xff006ab7 0xff016cb7 0xff0069b5 0xff0066b4 0xff0064b2 0xff0062b1 0xff005bad 0xff1d6cb3 0xfffffff8 0xff0364b5 0xffb0283e 0xff913252 0xff004fa8 0x963471c1 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0xf01357a7 0xff074da3 0xffc9262c 0xff3d3f7c 0xff518bbc 0xffcacbcf 0xff0056a9 0xff005dae 0xff0061b0 0xff0064b2 0xff0065b3 0xff0169b5 0xff006cb7 0xff0069b7 0xff3c90ca 0xffffffff 0xff1f86c7 0xff3090cb 0xffcfe6f3 0xff0a82c6 0xff007ec8 0xff0082ca 0xff0084cc 0xff0087ce 0xff0089cf 0xff008bd4 0xff008ed4 0xff0090d6 0xff0192d7 0xff0094d9 0xff0095d9 0xff0092d8 0xff0091d8 0xff0092d9 0xff0095d9 0xff0094d8 0xff0192d7 0xff0090d6 0xff008ed4 0xff008cd1 0xff0089cf 0xff0187ce 0xff0084cc 0xff007fc9 0xff0079c4 0xff007ac5 0xff067dc4 0xff9fcae7 0xff0066b7 0xfff5fafb 0xff95c4e2 0xff7fb6da 0xff0067b5 0xff0069b5 0xff0065b3 0xff0064b2 0xff0161b0 0xff0055a9 0xffd5e0e9 0xff8ab4d7 0xff254189 0xfff01b1e 0xff144c9e 0xff1055a6 0x0a72a8e5 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x6c2e6bba 0xff024fa6 0xff49417b 0xffd62223 0xff0050a9 0xffb8c5ce 0xff749dc1 0xff0056ac 0xff0060b0 0xff0163b1 0xff0065b3 0xff0068b5 0xff006ab6 0xff167abf 0xfff1f7f9 0xff0063b6 0xffd7eaf4 0xff3994cf 0xff228aca 0xff9fcdea 0xff007ac3 0xff0080c9 0xff0082cb 0xff0085cd 0xff0188ce 0xff008bd0 0xff008dd2 0xff008ed4 0xff0090d6 0xff0191d7 0xff0192d8 0xff0094d8 0xff0094d9 0xff0094d8 0xff0192d8 0xff0191d7 0xff0090d6 0xff008ed4 0xff018cd1 0xff008ad0 0xff0088ce 0xff0083cd 0xff007ac7 0xff48a3d7 0xffb9dbec 0xff1f8bca 0xff0070bf 0xffc3e0ed 0xffdbecf5 0xff1e81c2 0xff0068b6 0xff0069b7 0xff016bb7 0xff0068b5 0xff0065b3 0xff0163b1 0xff0059ad 0xff6198c9 0xfff3f2f3 0xff0054ad 0xffdb212a 0xff713966 0xff0050a9 0x872265b7 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0xd91052a0 0xff0051ac 0xffaf2c3d 0xff813354 0xff0263b5 0xffece4dd 0xff2974b4 0xff005cae 0xff0163b1 0xff0065b3 0xff0167b5 0xff006bb6 0xff0067b5 0xffb6d6ea 0xff75b1d9 0xff005fb3 0xffafd5eb 0xffe5f1f6 0xff69b1db 0xff0077c2 0xff1c8dce 0xff1289cd 0xff0083cc 0xff0186cd 0xff0088cf 0xff008bd0 0xff008cd2 0xff008ed4 0xff008fd5 0xff0190d6 0xff0090d6 0xff0191d7 0xff0090d6 0xff0190d6 0xff008fd5 0xff008ed4 0xff008cd2 0xff008bd0 0xff0088cf 0xff0084cc 0xff0e8ace 0xffd5eaf4 0xff82c0e2 0xff1185c9 0xffbddbee 0xff006cbc 0xff9ccae6 0xff3c93cb 0xff006dba 0xff0070ba 0xff006db8 0xff016ab6 0xff0067b4 0xff0065b3 0xff0060b0 0xff136bb4 0xfffffffa 0xff1975bd 0xff6d3868 0xffda202a 0xff0055ae 0xf10f56a9 0x01acd4f6 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x435b93da 0xff0650a4 0xff104f9e 0xffe31f1e 0xff354481 0xff4b8bc2 0xffe0dfdd 0xff0d67b1 0xff005ead 0xff0064b3 0xff0167b4 0xff006ab6 0xff016cb7 0xff0062b3 0xff9bc6e4 0xff8dc0e1 0xff4499ce 0xff81bcdf 0xff0071bf 0xff0074c2 0xffbfdfee 0xff1b8ece 0xff0082cb 0xff0084cc 0xff0083cd 0xff0087cd 0xff018bcf 0xff008bd0 0xff018dd3 0xff008dd3 0xff008ed4 0xff008fd5 0xff008ed4 0xff008dd4 0xff018dd2 0xff008cd1 0xff0089d0 0xff0082cc 0xff0083cd 0xff0081ca 0xfffafdfd 0xff1187cb 0xff0075c5 0xff8ec3e3 0xff92c6e2 0xff0070bd 0xff3c95cf 0xff62a8d4 0xff006db9 0xff006fb9 0xff006cb7 0xff0069b6 0xff0167b4 0xff0062b1 0xff0061b1 0xffe7ebef 0xff79acd3 0xff1c4692 0xfffd1716 0xff254c92 0xff0054a7 0x5d4185d3 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x8f3474c1 0xff0050aa 0xff4e4278 0xffe31e1e 0xff004e9f 0xff8cb1d0 0xffcbd3da 0xff0060b0 0xff0061b1 0xff0065b3 0xff0068b5 0xff006bb7 0xff006eb9 0xff0066b4 0xff5ba3d3 0xffa8cfe6 0xff0879c2 0xff0077c1 0xff047cc5 0xfff2f9fa 0xff1187c9 0xff0079c6 0xff007bc8 0xff7bc0e1 0xff1c93d3 0xff0388d0 0xff1993d5 0xff0089cf 0xff008bd0 0xff0087cf 0xff0086cf 0xff018cd1 0xff0089d1 0xff0089d0 0xff0088cf 0xff0086cf 0xffddeef5 0xff5fb2dd 0xff007bc8 0xff44a2d7 0xffb2d8ec 0xffd1e8f1 0xff4ca1d4 0xff006fbe 0xff0177c1 0xff0070bd 0xff006dbb 0xff0070ba 0xff006db8 0xff006cb7 0xff0069b5 0xff0064b2 0xff005caf 0xffc5d5e5 0xffb9d2e4 0xff0053a9 0xfff01b21 0xff783965 0xff0055ac 0xad246cbe 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0xdf165caa 0xff0055ac 0xff7b395f 0xffce232c 0xff0056ad 0xffa0bed6 0xffbfcfdc 0xff005fae 0xff0063b3 0xff0067b4 0xff006ab6 0xff016db8 0xff006eb9 0xff006db9 0xff006dba 0xff0075c0 0xff0072bf 0xff88c0e2 0xff6ab2db 0xffb3d8ed 0xffc0def0 0xff54aadb 0xffcfe7f2 0xff007cc8 0xff2496d3 0xffacd9ee 0xff0082cd 0xff0080cb 0xff90ccea 0xffb8ddee 0xff0080cb 0xff70bbe4 0xff5bb2df 0xff007ecb 0xff7ac0e3 0xff66b5e0 0xffa5d3eb 0xff007bc6 0xff0076c5 0xffc7e3f0 0xff0b7fc7 0xff0074c0 0xff0077c1 0xff0075bf 0xff0173bd 0xff0071ba 0xff006eb9 0xff016cb7 0xff006ab6 0xff0066b3 0xff005caf 0xffb2cbe1 0xffcadae9 0xff005bb3 0xffce2334 0xffa72e4b 0xff0059b0 0xf10c5aa9 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x166ca6e6 0xff0957a7 0xff0056aa 0xffa62e46 0xffaa2c41 0xff015eae 0xffb6cbdc 0xffc3d3e1 0xff0062b1 0xff0063b2 0xff0169b5 0xff006cb7 0xff006eb8 0xff006fba 0xff0172bb 0xff0174bd 0xff0071be 0xffb1d6ea 0xff0076c2 0xff0074c0 0xff1386cb 0xffbbdbed 0xff57abdb 0xff007cc8 0xff399fd6 0xff8bc6e6 0xff0076c7 0xffa2d4ed 0xff65b4de 0xffcee7f4 0xff007dca 0xff2897d4 0xffa3d3ec 0xff007cc8 0xffb0d8ed 0xff007ac6 0xffcce6f2 0xff007cc6 0xff007bc5 0xff278fcc 0xff99cae4 0xff0073bf 0xff0076c0 0xff0174bd 0xff0172bb 0xff006fba 0xff016db8 0xff006cb7 0xff0066b4 0xff005fb1 0xffb0cce2 0xffcfdce9 0xff0067b6 0xff9f2e4c 0xffd12432 0xff0058ab 0xff0054a7 0x27377ec9 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x3c397fc8 0xff085aaa 0xff0056a8 0xffb72a3b 0xffa92b41 0xff025fae 0xffa8c6dd 0xffd8e2e8 0xff0d6bb5 0xff0062b2 0xff016ab6 0xff006cb7 0xff006eb9 0xff0071ba 0xff0172bc 0xff0174bd 0xff0175bf 0xff0077c1 0xff007ac3 0xff0076c1 0xffcae4f2 0xff007bc5 0xff007bc5 0xff52a8d9 0xff60b1dc 0xffa6d2eb 0xff5aafdc 0xff007cc8 0xffbfe1f2 0xff007cc8 0xff007dc8 0xffc4e2f2 0xff72b9e1 0xff57acda 0xff0075c4 0xffafd6ec 0xff248ecc 0xff0079c3 0xff0078c3 0xff077bc3 0xff0075c0 0xff0174be 0xff0173bc 0xff0070ba 0xff006eb9 0xff006cb8 0xff0067b5 0xff0267b4 0xffc6d8e7 0xffcadae7 0xff0068b7 0xff9f2e4c 0xffe01f2b 0xff0956a5 0xff0055a9 0x5a2b71b7 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x583675b8 0xff0054a8 0xff0156a9 0xffb82a3b 0xffad2d42 0xff0059af 0xff9bc1dc 0xfff9f5f3 0xff297dbf 0xff005fb1 0xff006bb6 0xff016db8 0xff006fb9 0xff0071ba 0xff0173bc 0xff0074be 0xff0076c0 0xff0078c1 0xff087bc4 0xff55a6d5 0xff007ac2 0xff007ac3 0xff68b2dc 0xfff6fcfc 0xff58abda 0xff0079c3 0xff198dcd 0xff9fceea 0xff007cc7 0xff007bc5 0xffaad5eb 0xffcbe6f3 0xff007bc5 0xff007bc5 0xff2b92ce 0xff1885c8 0xff0078c1 0xff0078c1 0xff0075c0 0xff0074be 0xff0172bb 0xff0071ba 0xff006eb9 0xff006db8 0xff0064b3 0xff1573ba 0xffe9ecef 0xffb7d1e6 0xff005fb4 0xffa32f4d 0xffe11f2a 0xff1156a4 0xff0055aa 0x6b286eb2 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x593072b6 0xff0057a9 0xff0058ac 0xffac2e44 0xffd62229 0xff0053a5 0xff579dcf 0xfffffffa 0xff7fafd4 0xff0060af 0xff0068b6 0xff006db8 0xff006fb9 0xff0071ba 0xff0173bc 0xff0174be 0xff0076c0 0xff0078c1 0xff0076c1 0xff007ac3 0xff007ac4 0xff1b89ca 0xff3395d1 0xff0079c4 0xff007dc7 0xff208ecc 0xff57aad8 0xff007cc5 0xff007cc5 0xff2c92d0 0xff228dcc 0xff007ac4 0xff007bc4 0xff0078c2 0xff0077c2 0xff0078c1 0xff0076c0 0xff0074be 0xff0172bc 0xff0071bb 0xff006fb9 0xff006ab7 0xff0061b2 0xff65a2cd 0xfffffff8 0xff75aed8 0xff0058aa 0xffd52133 0xffd32333 0xff0958a9 0xff0057ab 0x863a7bbb 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x572e73b7 0xff045bab 0xff005baf 0xff83395f 0xffee1c1a 0xff334888 0xff0571bf 0xffdde7ec 0xffe9ecf0 0xff3385c0 0xff0062b4 0xff006bb8 0xff006fb9 0xff0071ba 0xff0173bc 0xff0074bd 0xff0075bf 0xff0077c0 0xff0078c1 0xff0079c2 0xff0079c3 0xff0078c2 0xff017bc4 0xff007bc4 0xff007bc3 0xff0079c3 0xff017cc4 0xff007bc4 0xff0079c2 0xff0078c2 0xff0079c3 0xff0079c2 0xff0178c1 0xff0176c0 0xff0075bf 0xff0074bd 0xff0073bc 0xff0070ba 0xff006db8 0xff0065b4 0xff207dbf 0xffdae3ed 0xfff0f1f2 0xff147cc4 0xff224d94 0xfff7191c 0xffa7304d 0xff005cac 0xff005bac 0x672370b5 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x01ffffff 0x00000000 0x38297bc5 0xff075dad 0xff005eb2 0xff57457a 0xfff61919 0xff893759 0xff005eb3 0xff69aad5 0xfffffcf7 0xffabcae1 0xff1e7bbe 0xff0066b5 0xff006bb8 0xff006fba 0xff0072bb 0xff0173bd 0xff0074be 0xff0075bf 0xff0077c1 0xff0177c1 0xff0178c1 0xff0079c2 0xff0079c2 0xff007ac3 0xff007ac3 0xff007ac3 0xff0079c2 0xff0079c2 0xff0178c1 0xff0177c1 0xff0177c1 0xff0175bf 0xff0174be 0xff0173bd 0xff0172bb 0xff006db9 0xff0067b7 0xff1577bd 0xff98c0dc 0xfffffdf7 0xff83b7db 0xff0062b6 0xff793c67 0xffff1412 0xff783d6b 0xff0061b5 0xff005bac 0x59418bcd 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x14529adc 0xe00d61ad 0xff005cb1 0xff1458a2 0xffc4283a 0xffea1b21 0xff3b4983 0xff006abd 0xff97c4df 0xfffdf8f4 0xffb9d2e3 0xff378ac5 0xff0069b8 0xff006ab7 0xff006eba 0xff0071ba 0xff0073bd 0xff0174be 0xff0075bf 0xff0076bf 0xff0076bf 0xff0077c0 0xff0077c1 0xff0178c1 0xff0077c1 0xff0077c0 0xff0076bf 0xff0076bf 0xff0075bf 0xff0174be 0xff0072bb 0xff0070ba 0xff006bb8 0xff006ab8 0xff2c85c2 0xffa9c8e1 0xfffffaf5 0xffaccde3 0xff0072bf 0xff2d4d8f 0xffe81d26 0xffdf212c 0xff24569a 0xff005fb5 0xee0c61ad 0x316aaeeb 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x982d7ec7 0xff005cae 0xff0062b6 0xff55487d 0xffe81c24 0xffce2531 0xff274d91 0xff006bba 0xff79b3d9 0xffe9eef0 0xfff4f3f2 0xff85b6d9 0xff3289c5 0xff0470ba 0xff0069b7 0xff006dba 0xff006fba 0xff0070bb 0xff0072bc 0xff0073be 0xff0073bc 0xff0073bc 0xff0073bc 0xff0072be 0xff0072bc 0xff006fba 0xff006dbb 0xff006bb7 0xff0270ba 0xff2a86c3 0xff7cb2d8 0xffeceeef 0xfff1f2f2 0xff8bbdde 0xff0373c0 0xff1c5299 0xffc52739 0xfffa191b 0xff6f416e 0xff0063b9 0xff005daf 0xae2a7dc5 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x474b9ae3 0xdb0761ae 0xff005fb1 0xff045fad 0xff7f3c66 0xffee1c20 0xffbe293f 0xff47487f 0xff0362b1 0xff4198cf 0xff9dc6e3 0xffe6edf0 0xffe6ebee 0xffb2cfe4 0xff81b4d7 0xff579fce 0xff358cc6 0xff1c80c3 0xff127bbf 0xff0e79be 0xff0f78be 0xff117abe 0xff1b80c0 0xff348cc6 0xff519cce 0xff7db3d8 0xffaccbe1 0xffe2e9ee 0xffedf0f1 0xffa6cce5 0xff4c9ed5 0xff0368b5 0xff3d4b86 0xffb52b43 0xfffa171c 0xff91385b 0xff0d5ca7 0xff0061b5 0xf00a65b0 0x594097dd 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x7a2d81ca 0xf00a65b1 0xff0061b5 0xff065ead 0xff6f426f 0xffd42331 0xffe91c25 0xff903556 0xff384c89 0xff0360ac 0xff2389c9 0xff5ea9d7 0xff90c0e0 0xffbcd7e9 0xffe0e6ed 0xfff3f0f2 0xfff0eff1 0xffe7ebef 0xffe5ecf0 0xffeeeef0 0xfff3f1f3 0xffe4e9ee 0xffc0d8e8 0xff95c4e0 0xff64abd9 0xff288ccb 0xff0264af 0xff304f8e 0xff89375c 0xffe61d27 0xffe31f2a 0xff7c3e68 0xff105ea6 0xff0062b5 0xff0c69b4 0x801873c2 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x7b277dc7 0xff0d67b4 0xff0061b4 0xff0064b6 0xff375391 0xff91395b 0xfffd1619 0xffff171a 0xffbb283f 0xff813a60 0xff4b487f 0xff0e59a3 0xff0068bd 0xff006ec1 0xff0078c3 0xff007ac6 0xff007ac6 0xff0079c5 0xff006fc2 0xff0069be 0xff085da6 0xff444c84 0xff7d3a64 0xffb62a43 0xfffa181c 0xffff1415 0xff9d3556 0xff42518c 0xff0066b7 0xff0064b6 0xff0364b3 0x963788d0 0x0a89c6f6 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x573385cd 0xd6247eca 0xff0061b0 0xff0063b6 0xff0068bc 0xff215a9d 0xff634978 0xff983658 0xffd52332 0xffff1212 0xffff0f0d 0xfffc171b 0xffeb1b25 0xffe51c27 0xffe51c27 0xffeb1b26 0xfff9181c 0xffff110d 0xffff1010 0xffdc222e 0xff9e3654 0xff674678 0xff26599c 0xff0069ba 0xff0066b7 0xff0060b2 0xe2207cc7 0x612b81c8 0x01a1d2fb 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x0d6aafee 0x630f6ab4 0xc52b85cc 0xff0266b4 0xff0063b5 0xff0065b8 0xff0068bb 0xff006abe 0xff0665b2 0xff1e5da2 0xff29589a 0xff355694 0xff355694 0xff2c5899 0xff1d5ca1 0xff0964b0 0xff006bbd 0xff0069bc 0xff0065bb 0xff0062b3 0xff0065b4 0xcb2380cc 0x732e87ce 0x1c6db8f3 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x223a83bc 0x623383c2 0x9e2678bd 0xc71771b7 0xd7086ab7 0xfc1774bb 0xff0c6fb9 0xff056db8 0xff056cb8 0xff0a6db9 0xff1b76bd 0xd60569b4 0xc81470b8 0xa12076ba 0x6e3c85bf 0x2d458ecb 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000 0x00000000"

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
dir_chromium="$(ls -d "$SCRIPT_DIR"/*chromium* | grep -v .tar | head -n1 )"
dir_VirtualGL="$(ls "$SCRIPT_DIR"/VirtualGL/bin/vglrun )"
DISPLAY_OLD=$(echo $DISPLAY)

if [[ "$DISPLAY_OLD" == "" ]]; then
    echo -e "Error: The DISPLAY environment variable is missing. Enter \nExample: DISPLAY=:0 $SCRIPT_DIR/InfoDoc.sh"
    exit 1
fi

if [[ "$dir_VirtualGL" == "" ]]; then
    echo "Error: VirtualGL launch file missing"
    exit 1
fi

if [[ "$dir_chromium" == "" ]]; then
    echo "Error: Chromium launch file missing"
    exit 1
fi

# Basic logic
check_deps
make_xdotool_xseticon


unique_id=$(date +%N)
title_InfoDoc="InfoDoc id=$unique_id"

display=$(xdpyinfo | grep dimensions | awk '{split($2, a, "x"); print a[1] "x" a[2]}');

Xephyr -br -ac -noreset -screen "$display" -resizeable -title "$title_InfoDoc" :$unique_id &
XEYPH_PID=$!

SECONDS=0
# Wait for the window to appear
#while ! xdotool search --name "$title_InfoDoc" > /dev/null 2>&1; do
while ! "$SCRIPT_DIR/xdotool_xseticon" search --name "$title_InfoDoc" > /dev/null 2>&1; do
    sleep 0.1;
    echo "window --name: $title_InfoDoc"
    (( SECONDS >= 60 )) && { echo "timeout 60 s"; exit 1; }
done

#window_id=$(xdotool search --name "$title_InfoDoc");
window_id=$("$SCRIPT_DIR/xdotool_xseticon" search --name "$title_InfoDoc");

echo "window_id: $window_id";

"$SCRIPT_DIR/xdotool_xseticon" _NET_WM $window_id rename "InfoDoc"
"$SCRIPT_DIR/xdotool_xseticon" xseticon $window_id $input_png

#xprop -id $window_id
# //-----------------------
# SCRIPT_DIR="$(dirname "$(realpath "$0")")"
# echo "$image_icon" | base64 -d > "$SCRIPT_DIR/set_icon010.png";
# xseticon -id "$window_id" "$SCRIPT_DIR/set_icon010.png";
# rm "$SCRIPT_DIR/set_icon010.png"
# //-----------------------

export DISPLAY=:$unique_id ;

start_resize() {
#   --start-maximized --kiosk --force-device-scale-factor=1.5
#     rm -rf /tmp/chromium-new-sessionon;
#     nohup chromium --user-data-dir=/tmp/chromium-new-sessionon --app=http://stuk/InfoDoc --Auto >/dev/null 2>&1 &
    chromium_sessionon="chromium-new-sessionon"
    if [[ "$USER" == root ]]; then
    chromium_sessionon="chromium_sessionon_root"
    fi
    rm -rf "$dir_chromium/$chromium_sessionon";
    nohup bash << EOF_BASH > /dev/null 2>&1 &
    if [[ "$XDG_SESSION_TYPE" == x11 || "$XDG_SESSION_TYPE" == X11 ]]; then
        "$dir_VirtualGL" -d $(ls /dev/dri/card* | tail -1) "$dir_chromium/chrome" \
        --user-data-dir="$dir_chromium/$chromium_sessionon" \
        --no-sandbox \
        --app="file://$SCRIPT_DIR/Demo/index.htm" \
        --disable-web-security \
        --test-type \
        --kiosk \
        --no-zygote
    else
        "$dir_chromium/chrome" \
        --user-data-dir="$dir_chromium/$chromium_sessionon" \
        --no-sandbox \
        --app="file://$SCRIPT_DIR/Demo/index.htm" \
        --disable-web-security \
        --test-type \
        --kiosk \
        --no-zygote
    fi
EOF_BASH
    echo "$!"
}

start_pid=$(start_resize);
pid=$(ps -o pid= --ppid "$start_pid")

SECONDS=0
# Wait for the window to appear
#while ! xdotool search --name "$title_InfoDoc" > /dev/null 2>&1; do
while ! "$SCRIPT_DIR/xdotool_xseticon" search --pid "$pid" > /dev/null 2>&1; do
    sleep 0.1;
    echo "pid chrome= $pid"
    pid=$(ps -o pid= --ppid "$start_pid")
    (( SECONDS >= 60 )) && { echo "timeout 60 s"; exit 1; }
done

# minimize the window from full-screen mode and set its dimensions to half the width of the entire display
# DISPLAY=$DISPLAY_OLD "$SCRIPT_DIR/xdotool_xseticon" _NET_WM $window_id reduce
# DISPLAY=$DISPLAY_OLD "$SCRIPT_DIR/xdotool_xseticon" windowsize $window_id $(xdpyinfo | grep dimensions | awk '{split($2, a, "x"); print a[1]/2 " " a[2]}')
# Option to set GIF animation on the window icon. Uncomment and check how it works in your distribution. Replace 6 with 20 or remove 6.
# DISPLAY=$DISPLAY_OLD "$SCRIPT_DIR/xdotool_xseticon" xseticon_gif "$window_id" "$SCRIPT_DIR/Images/Image.txt" 6 > /dev/null 2>&1 &
# Comment out # at your discretion. Enables and disables the shared clipboard via xclip
sync_buffer_xephyr &

while true; do
    #xrandr | grep '*' | awk '{print $1}'
    #xdotool getwindowgeometry "$window_id"
    size=$(xdpyinfo | grep dimensions | awk '{print $2}' | sed 's/x/ /')
#    echo "Размер экрана: $size"
#    echo "Процесс браузера PID: $pid"

#    window_id=$(xdotool search --all --pid $pid | awk 'NR!=1' );
    window_id=$("$SCRIPT_DIR/xdotool_xseticon" search --pid $pid | awk 'NR!=1' );
    #echo "window_id: $(xdotool search --all --pid $pid)"

    for id in $window_id; do
#         echo "ID окна Chromium: $id"

#        size_Chromium=$(xdotool getwindowgeometry $id | grep 'Geometry' | awk '{print $2}' | sed 's/x/ /');
         size_Chromium=$("$SCRIPT_DIR/xdotool_xseticon" getwindowgeometry $id | grep 'Geometry' | awk '{print $2}' | sed 's/x/ /');

         #echo "$(xdotool getwindowgeometry $id | grep 'Geometry' | awk '{print $2}' | sed 's/x/ /')"
         #echo "$("$SCRIPT_DIR/xdotool_xseticony" $id | grep 'Geometry' | awk '{print $2}' | sed 's/x/ /')"
#        echo "$size_Chromium"

        if [[ "$size_Chromium" != "$size" ]]; then
            "$SCRIPT_DIR/xdotool_xseticon" windowmove $id 0 0
            "$SCRIPT_DIR/xdotool_xseticon" windowsize $id $size

            #xdotool windowmove $id 0 0
            #xdotool windowsize $id $size
            #xdotool getwindowgeometry "$window_id"
        fi
    done

    sleep 1;
    # Check if the process is alive, for example:
    if ! kill -0 "$pid" 2>/dev/null; then
        echo "The browser has terminated."
        break
    fi
done
exit 0
