
## Kerisy Framework
Kerisy is a high-level web framework for [D Programming Language](http://dlang.org/). It encourages rapid development and clean, pragmatic design and make you building high-performance web applications quickly and easily. It also provides a beautifully expressive and easy to use foundation for your next website or API.
![Framework](framework.png)


## Getting Started

### Create a project
```bash
git clone https://github.com/kerisy/app.git
cd app/
dub run
```

Open the URL with the browser:
```bash
http://localhost:8080/
```

### Router config
config/routes
```conf
#
# [GET,POST,PUT...]    path    controller.action
#

GET     /               index.index
GET     /users          user.list
POST    /user/login     user.login
*       /images         staticDir:public/images

```

### Add Controller
```D
module controller.index;

import kerisy;

class IndexController : Controller
{
    mixin MakeController;

    @Action
    string index()
    {
        return "Hello Kerisy!";
    }
}
```

For more, see [kerisy-app](https://github.com/kerisy/app).

## Community
- [Issues](https://github.com/kerisy/kerisy/issues)
- QQ Group: 184183224 
- [D语言中文社区](https://forums.dlangchina.com/)

