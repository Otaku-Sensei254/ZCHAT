[app.js](http://app.js)

// Include phoenix\_html to handle method=PUT/DELETE in forms and buttons.  
import "phoenix\_html"

// Establish Phoenix Socket and LiveView configuration.  
import {Socket} from "phoenix"  
import {LiveSocket} from "phoenix\_live\_view"  
import topbar from "../vendor/topbar"  
//import './user\_socket.js'  
let csrfToken \= document.querySelector("meta\[name='csrf-token'\]").getAttribute("content")

import userSocket from "./user\_socket";

// Define Hooks object  
let Hooks \= {};

Hooks.ChatHook \= {  
 mounted() {  
   const conversationId \= *this*.el.dataset.conversationId;  
   if (\!conversationId) return;

   *this*.channel \= userSocket.channel(\`conversation:${conversationId}\`, {});

   // Listen for new messages from the channel  
   *this*.channel.on("new\_message", (*payload*) \=\> {  
     *this*.pushEvent("display\_new\_message", *payload*);  
   });

   // Handle events from the server to send a message  
   *this*.handleEvent("send\_to\_channel", ({ *content* }) \=\> {  
     *this*.channel.push("new\_message", { content });  
   });

   *this*.channel.join()  
     .receive("ok", () \=\> console.log(\`Joined conversation:${conversationId}\`))  
     .receive("error", ({ *reason* }) \=\> console.error("Failed to join", *reason*));  
 },  
 destroyed() {  
   if (*this*.channel) {  
     *this*.channel.leave();  
   }  
 }  
};

// Hooks.ChatChannel \= {  
//   mounted() {  
//     let conversationId \= this.el.dataset.conversationId  
//     this.channel \= joinConversation(conversationId, (msg) \=\> {  
//       this.pushEvent("new\_message", msg)  
//     })  
//   },

//   destroyed() {  
//     this.channel.leave()  
//   }  
// }  
//

Hooks.NotificationsHook \= {  
 mounted() {  
   *this*.handleEvent("new\_notification", ({ *notification* }) \=\> {  
     // Update notification badge  
     const badge \= document.querySelector("\#notification-badge");  
     if (badge) {  
       badge.classList.remove("hidden");  
       const count \= badge.textContent;  
       badge.textContent \= count \=== "" ? "1" : (parseInt(count) \+ 1).toString();  
     }  
      
     // If modal is open, refresh notifications  
     const modal \= document.querySelector("\#notifications-modal");  
     if (modal && \!modal.classList.contains("hidden")) {  
       *this*.pushEvent("load\_notifications", {});  
     }  
   });

   *this*.handleEvent("refresh\_notifications", () \=\> {  
     // If modal is open, refresh notifications  
     const modal \= document.querySelector("\#notifications-modal");  
     if (modal && \!modal.classList.contains("hidden")) {  
       *this*.pushEvent("load\_notifications", {});  
     }  
   });  
 }  
};

Hooks.VideoAutoplay \= {  
 mounted() {  
   *this*.observer \= **new** *IntersectionObserver*(  
     (*entries*) \=\> {  
       let entry \= *entries*\[0\];  
       if (entry.isIntersecting) {  
         // Video is on screen  
         *this*.el.play().catch((*error*) \=\> {  
           // Autoplay was prevented (browser restrictions)  
           console.log("Autoplay prevented: ", *error*);  
         });  
       } else {  
         // Video is off screen  
         *this*.el.pause();  
       }  
     },  
     { threshold: 0.5 } // 50% of the video must be visible  
   );

   *this*.observer.observe(*this*.el);  
 },  
 destroyed() {  
   // Stop observing when the element is removed  
   *this*.observer.disconnect();  
 },  
};

//auto scroll for chat messages  
Hooks.ScrollToBottom \= {  
 mounted() {  
   *this*.el.scrollTop \= *this*.el.scrollHeight;  
 },  
 updated() {  
   *this*.el.scrollTop \= *this*.el.scrollHeight;  
 }  
}  
// Create the LiveSocket ONCE, passing the Hooks  
let liveSocket \= **new** LiveSocket("/live", Socket, {  
 params: { \_csrf\_token: csrfToken },  
 hooks: Hooks,  
});

// Show progress bar on live navigation and form submits  
topbar.config({barColors: {0: "\#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})  
window.addEventListener("phx:page-loading-start", *\_info* \=\> topbar.show(300))  
window.addEventListener("phx:page-loading-stop", *\_info* \=\> topbar.hide())

// connect if there are any LiveViews on the page  
liveSocket.connect()

window.liveSocket \= liveSocket

User\_socket.js

// Include phoenix\_html to handle method=PUT/DELETE in forms and buttons.  
import "phoenix\_html"

// Establish Phoenix Socket and LiveView configuration.  
import {Socket} from "phoenix"  
import {LiveSocket} from "phoenix\_live\_view"  
import topbar from "../vendor/topbar"  
//import './user\_socket.js'  
let csrfToken \= document.querySelector("meta\[name='csrf-token'\]").getAttribute("content")

import userSocket from "./user\_socket";

// Define Hooks object  
let Hooks \= {};

Hooks.ChatHook \= {  
 mounted() {  
   const conversationId \= *this*.el.dataset.conversationId;  
   if (\!conversationId) return;

   *this*.channel \= userSocket.channel(\`conversation:${conversationId}\`, {});

   // Listen for new messages from the channel  
   *this*.channel.on("new\_message", (*payload*) \=\> {  
     *this*.pushEvent("display\_new\_message", *payload*);  
   });

   // Handle events from the server to send a message  
   *this*.handleEvent("send\_to\_channel", ({ *content* }) \=\> {  
     *this*.channel.push("new\_message", { content });  
   });

   *this*.channel.join()  
     .receive("ok", () \=\> console.log(\`Joined conversation:${conversationId}\`))  
     .receive("error", ({ *reason* }) \=\> console.error("Failed to join", *reason*));  
 },  
 destroyed() {  
   if (*this*.channel) {  
     *this*.channel.leave();  
   }  
 }  
};

// Hooks.ChatChannel \= {  
//   mounted() {  
//     let conversationId \= this.el.dataset.conversationId  
//     this.channel \= joinConversation(conversationId, (msg) \=\> {  
//       this.pushEvent("new\_message", msg)  
//     })  
//   },

//   destroyed() {  
//     this.channel.leave()  
//   }  
// }  
//

Hooks.NotificationsHook \= {  
 mounted() {  
   *this*.handleEvent("new\_notification", ({ *notification* }) \=\> {  
     // Update notification badge  
     const badge \= document.querySelector("\#notification-badge");  
     if (badge) {  
       badge.classList.remove("hidden");  
       const count \= badge.textContent;  
       badge.textContent \= count \=== "" ? "1" : (parseInt(count) \+ 1).toString();  
     }  
      
     // If modal is open, refresh notifications  
     const modal \= document.querySelector("\#notifications-modal");  
     if (modal && \!modal.classList.contains("hidden")) {  
       *this*.pushEvent("load\_notifications", {});  
     }  
   });

   *this*.handleEvent("refresh\_notifications", () \=\> {  
     // If modal is open, refresh notifications  
     const modal \= document.querySelector("\#notifications-modal");  
     if (modal && \!modal.classList.contains("hidden")) {  
       *this*.pushEvent("load\_notifications", {});  
     }  
   });  
 }  
};

Hooks.VideoAutoplay \= {  
 mounted() {  
   *this*.observer \= **new** *IntersectionObserver*(  
     (*entries*) \=\> {  
       let entry \= *entries*\[0\];  
       if (entry.isIntersecting) {  
         // Video is on screen  
         *this*.el.play().catch((*error*) \=\> {  
           // Autoplay was prevented (browser restrictions)  
           console.log("Autoplay prevented: ", *error*);  
         });  
       } else {  
         // Video is off screen  
         *this*.el.pause();  
       }  
     },  
     { threshold: 0.5 } // 50% of the video must be visible  
   );

   *this*.observer.observe(*this*.el);  
 },  
 destroyed() {  
   // Stop observing when the element is removed  
   *this*.observer.disconnect();  
 },  
};

//auto scroll for chat messages  
Hooks.ScrollToBottom \= {  
 mounted() {  
   *this*.el.scrollTop \= *this*.el.scrollHeight;  
 },  
 updated() {  
   *this*.el.scrollTop \= *this*.el.scrollHeight;  
 }  
}  
// Create the LiveSocket ONCE, passing the Hooks  
let liveSocket \= **new** LiveSocket("/live", Socket, {  
 params: { \_csrf\_token: csrfToken },  
 hooks: Hooks,  
});

// Show progress bar on live navigation and form submits  
topbar.config({barColors: {0: "\#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})  
window.addEventListener("phx:page-loading-start", *\_info* \=\> topbar.show(300))  
window.addEventListener("phx:page-loading-stop", *\_info* \=\> topbar.hide())

// connect if there are any LiveViews on the page  
liveSocket.connect()

window.liveSocket \= liveSocket

[chat.ex](http://chat.ex)  context  
defmodule *Zchat.Chat* do  
 import *Ecto*.*Query*, warn: false  
 alias *Zchat*.*Repo*  
 alias *Zchat*.*Chat*.{*Message*, *Conversation*, *ConversationMember*}  
 alias *Zchat*.*Accounts*.*User*

 \# \--- CONVERSATIONS \---

 def get\_conversation\!(id) do  
   *Conversation*  
   |\> *Repo*.get\!(id)  
   |\> *Repo*.preload(conversation\_members: :user)  
 end

 def list\_user\_conversations(%*User*{} \= user), do: list\_user\_conversations(user.id)

 def list\_user\_conversations(user\_id) do  
   from(c in *Conversation*,  
     join: cm in assoc(c, :conversation\_members),  
     where: cm.user\_id \== ^user\_id,  
     preload: \[conversation\_members: :user\],  
     order\_by: \[desc: c.updated\_at\]  
   )  
   |\> *Repo*.all()  
 end

 \# Helper to find/create private chat  
 def get\_or\_create\_private\_conversation(user\_id\_1, user\_id\_2) do  
   case find\_private\_conversation(user\_id\_1, user\_id\_2) do  
     nil \-\> create\_private\_conversation(user\_id\_1, user\_id\_2)  
     conversation \-\> {:ok, conversation}  
   end  
 end

 defp create\_private\_conversation(uid1, uid2) do  
   *Repo*.transaction(fn \-\>  
     \# Set type to 'direct'  
     conv \= *Repo*.insert\!(%*Conversation*{type: "direct"})  
     *Repo*.insert\!(%*ConversationMember*{conversation\_id: conv.id, user\_id: uid1})  
     *Repo*.insert\!(%*ConversationMember*{conversation\_id: conv.id, user\_id: uid2})  
     conv  
   end)  
 end

 defp find\_private\_conversation(u1, u2) do  
   query \= from cm in *ConversationMember*,  
     where: cm.user\_id in \[^u1, ^u2\],  
     group\_by: cm.conversation\_id,  
     having: count(cm.user\_id) \== 2,  
     select: cm.conversation\_id

   \# This is a simplified check; in production you'd ensure no 3rd member exists  
   case *Repo*.one(query) do  
     nil \-\> nil  
     id \-\> *Repo*.get(*Conversation*, id)  
   end  
 end

 def subscribe\_to\_conversation(conversation) do  
   *Phoenix*.*PubSub*.subscribe(*Zchat*.*PubSub*, "conversation:\#{conversation.id}")  
 end

 def member\_of\_conversation?(%*User*{} \= user, conversation\_id) do  
   from(cm in *ConversationMember*,  
     where: cm.user\_id \== ^user.id and cm.conversation\_id \== ^conversation\_id  
   )  
   |\> *Repo*.exists?()  
 end

 \# \--- MESSAGES \---

 def list\_messages(conversation\_id) when is\_binary(conversation\_id) or is\_integer(conversation\_id) do  
   from(m in *Message*,  
     where: m.conversation\_id \== ^conversation\_id,  
     order\_by: \[asc: m.inserted\_at\],  
     preload: \[:user\]  
   )  
   |\> *Repo*.all()  
 end  
 def list\_messages(%*Conversation*{} \= conversation), do: list\_messages(conversation.id)

 def create\_message(user, conversation, attrs) do  
     attrs\_with\_ids \= *Map*.merge(attrs, %{  
       "user\_id" \=\> user.id,  
       "conversation\_id" \=\> conversation.id  
     })

   *IO*.inspect(attrs\_with\_ids, label: "Creating message with attrs")  
   %*Message*{}  
   |\> *Message*.changeset(attrs\_with\_ids)  
   |\> *IO*.inspect(label: "Message changeset" )  
   |\> *Ecto*.*Changeset*.put\_assoc(:user, user)  
   |\> *Ecto*.*Changeset*.put\_assoc(:conversation, conversation)  
   |\> *Repo*.insert()  
   |\> *IO*.inspect(label: "Inserted message result")  
 end

 def broadcast\_message(conversation, message) do  
   message \= *Repo*.preload(message, :user)  
   *Phoenix*.*PubSub*.broadcast(  
     *Zchat*.*PubSub*,  
     "conversation:\#{conversation.id}",  
     {:new\_message, message}  
   )  
   \# Bump the updated\_at so it moves to top of sidebar  
   from(c in *Conversation*, where: c.id \== ^conversation.id)  
   |\> *Repo*.update\_all(set: \[updated\_at: *DateTime*.utc\_now()\])  
 end

  @doc """  
 Checks if a user is a member of a specific conversation.  
 Used by ConversationChannel to authorize joins.  
 """  
 def member\_of\_conversation?(user, conversation\_id) do  
   query \= from cm in *ConversationMember*,  
     where: cm.user\_id \== ^user.id and cm.conversation\_id \== ^conversation\_id

   *Repo*.exists?(query)  
 end  
end

Within the channel folder  
Conversation\_channel.ex  
defmodule *ZchatWeb.ConversationChannel* do  
 use *ZchatWeb*, :channel  
 alias *Zchat*.*Chat*  
 alias *Zchat*.*Accounts*.*User*

 \# Join a conversation channel  
 \# who can join the topic  
 def join("conversation:" \<\> conversation\_id, \_params, socket) do  
   user \= socket.assigns.current\_user  
   conversation\_id \= *String*.to\_integer(conversation\_id)

   \# validate user is allowed to join convo  
   if *Chat*.member\_of\_conversation?(user, conversation\_id) do  
     {:ok, assign(socket, :conversation\_id, conversation\_id)}  
   else  
     \# if not authorized  
     {:error, %{reason: "unauthorized"}}  
   end  
 end

 \# handle coming in messages  
 def handle\_in("new\_message", %{"content" \=\> content}, socket) do  
   user \= socket.assigns.current\_user  
   conversation\_id \= socket.assigns.conversation\_id  
   conversation \= *Chat*.get\_conversation\!(conversation\_id)

   case *Chat*.create\_message(user, conversation, %{"content" \=\> content}) do  
     {:ok, message} \-\>  
       broadcast\!(socket, "new\_message", %{  
         id: message.id,  
         content: message.content,  
         username: user.username,  
         user: %{id: user.id, username: user.username, avatar\_url: user.avatar\_url},  
         inserted\_at: message.inserted\_at  
       })

       {:noreply, socket}

     {:error, \_changeset} \-\>  
       {:reply, {:error, %{errors: "Failed to save"}}, socket}  
   end  
 end  
end

User\_socker.ex  
defmodule *ZchatWeb.UserSocket* do  
 use *Phoenix*.*Socket*

 \#\# Channels  
 channel "conversation:\*", *ZchatWeb*.*ConversationChannel*

 @impl true  
 def connect(%{"token" \=\> token}, socket, \_connect\_info) when is\_binary(token) do  
   with {:ok, token\_binary} \<- *Base*.url\_decode64(token),  
        {:ok, user} \<- *Zchat*.*Accounts*.get\_user\_by\_session\_token(token\_binary) do  
     {:ok, assign(socket, :current\_user, user)}  
   else  
     \_ \-\> :error  
   end  
 end

 def connect(\_params, \_socket, \_connect\_info), do: :error

 @impl true  
 \# This id allows broadcasting to all of a user’s sockets if needed  
 def id(socket), do: "users\_socket:\#{socket.assigns.current\_user.id}"  
end

Inside chat/  
Chat\_live.ex  
defmodule *ZchatWeb.Chat.ChatLive* do  
 use *ZchatWeb*, :live\_view

 alias *Zchat*.*Chat*  
 alias *Zchat*.*Accounts*  
 alias *Zchat*.*Chat*.*Message*  
 alias *Zchat*.*Chat*.*Conversation*

   @impl true

   def mount(\_params, \_session, socket) do

     current\_user \= socket.assigns.current\_user

     conversations \= *Chat*.list\_user\_conversations(current\_user)  
     if connected?(socket), do: *Phoenix*.*PubSub*.subscribe(*Zchat*.*PubSub*, "user\_\#{current\_user.id}")  
     {:ok,  
      socket

      |\> assign(:conversations, conversations)  
      |\> assign(:conversation, nil)  
      |\> assign(:form, to\_form(*Chat*.*Message*.changeset(%*Message*{}, %{})))  
      |\> stream(:messages, \[\])}  
   end

   @impl true

   def handle\_params(%{"id" \=\> conversation\_id}, \_uri, socket) do  
     conversation \= *Chat*.get\_conversation\!(conversation\_id)  
     messages \= *Chat*.list\_messages(conversation)  
     if connected?(socket) do  
       *Chat*.subscribe\_to\_conversation(conversation)  
     end  
     socket \=  
       socket  
       |\> assign(:conversation, conversation)  
       |\> stream(:messages, messages, reset: true)  
     {:noreply, socket}  
   end

   @impl true  
   def handle\_params(\_params, \_uri, socket) do  
     case socket.assigns.conversations do  
       \[first\_conversation | \_\] \-\>  
         {:noreply, push\_patch(socket, to: \~p"/chat/\#{first\_conversation.id}")}  
       \[\] \-\>  
         {:noreply, socket}  
     end  
   end

 @impl true  
 def handle\_event("send\_message", %{"message" \=\> params}, socket) do  
   user \= socket.assigns.current\_user  
   conversation \= socket.assigns.conversation

   \# Check if content exists to avoid empty messages  
   if params\["content"\] && *String*.trim(params\["content"\]) \!= "" do  
     case *Chat*.create\_message(user, conversation, params) do  
       {:ok, message} \-\>  
         *Chat*.broadcast\_message(conversation, message)  
         \# Reset form explicitly  
         {:noreply, assign(socket, :form, to\_form(*Chat*.*Message*.changeset(%*Message*{}, %{})))}

       {:error, changeset} \-\>  
         {:noreply, assign(socket, :form, to\_form(changeset))}  
     end  
   else  
     {:noreply, socket}  
   end  
 end

 @impl true  
 def handle\_info({:new\_message, message}, socket) do  
   \# Only append if we are viewing this conversation  
   if socket.assigns.conversation && socket.assigns.conversation.id \== message.conversation\_id do  
     {:noreply,  
      socket  
      |\> stream\_insert(:messages, message)  
      |\> push\_event("scroll-to-bottom", %{})}  
   else  
     {:noreply, socket}  
   end  
 end  
 @impl true  
 def handle\_event("validate", %{"message" \=\> params}, socket) do  
   changeste \=  
     %*Message*{}  
     |\> *Chat*.*Message*.changeset(params)  
     |\> *Map*.put(:action, :validate)

   {:noreply, assign(socket, :form, to\_form(changeste))}  
 end

 \#helper functions  
  \# \--- UI HELPERS \---  
 defp get\_chat\_title(conversation, current\_user) do  
   if conversation.type \== "group" do  
     conversation.name || "Unnamed Group"  
   else  
     other \= *Enum*.find(conversation.conversation\_members, fn m \-\> m.user\_id \!= current\_user.id end)  
     if other, do: other.user.username, else: "Unknown User"  
   end  
 end

  defp get\_chat\_avatar(conversation, current\_user) do  
   if conversation.type \== "group" do  
     "group"  
   else  
     other \= *Enum*.find(conversation.conversation\_members, fn m \-\> m.user\_id \!= current\_user.id end)  
     if other && other.user.avatar\_url, do: other.user.avatar\_url, else: "/images/default\_avatar.png"  
   end  
 end

end

Chat\_live.html.heex  
\<div *class*\="flex h-\[calc(100vh-4rem)\] bg-white dark:bg-zinc-900 border-t border-gray-200 dark:border-zinc-800"\>  
  \<\!-- LEFT SIDEBAR: Conversation List \--\>  
 \<div *class*\="w-20 md:w-80 border-r border-gray-200 dark:border-zinc-800 flex flex-col"\>  
   \<\!-- Sidebar Header \--\>  
   \<div *class*\="p-4 border-b border-gray-200 dark:border-zinc-800 bg-gray-50 dark:bg-zinc-900/50 hidden md:block"\>  
     \<h2 *class*\="font-bold text-gray-800 dark:text-gray-100"\>Messages\</h2\>  
   \</div\>  
    
   \<\!-- List of Conversations \--\>  
   \<div *class*\="flex-1 overflow-y-auto"\>  
     \<%= for conv \<- @conversations do %\>  
       \<%  
          \# Determine Display Name & Avatar for the sidebar item  
          \# If Group: Use group name/icon. If Direct: Use other user's name/avatar.  
          is\_group \= conv.type *\==* "group"  
          other\_member \= Enum.find(conv.conversation\_members, &(&1.user.id \!\= @current\_user.id))  
           
          display\_name \= if is\_group, do: conv.name || "Unnamed Group", else: (other\_member && other\_member.user.username) || "Unknown"  
          avatar\_url \= if is\_group, do: nil, else: (other\_member && other\_member.user.avatar\_url) || "/images/default\_avatar.png"  
           
          \# Check if this conversation is the currently active one  
          is\_active \= @conversation && conv.id \=*\=* @conversation.id  
       %\>  
        
       \<.link navigate\={\~p"/chat/\#{conv.id}"} class\={\[  
         "flex items-center justify-center md:justify-start gap-3 p-3 md:p-4 border-b border-gray-100 dark:border-zinc-800 hover:bg-gray-50 dark:hover:bg-zinc-800 transition",  
         is\_active && "bg-blue-50 dark:bg-blue-900/20 md:border-l-4 md:border-l-blue-500"  
       \]}\>  
          
         \<\!-- Sidebar Avatar \--\>  
         \<%= if is\_group do %\>  
           \<div *class*\="w-10 h-10 rounded-full bg-blue-100 dark:bg-blue-900 flex items-center justify-center text-blue-600 dark:text-blue-300 shrink-0"\>  
             \<svg *xmlns*\="http://www.w3.org/2000/svg" *class*\="w-6 h-6" *fill*\="none" *viewBox*\="0 0 24 24" *stroke*\="currentColor"\>  
               \<path *stroke-linecap*\="round" *stroke-linejoin*\="round" *stroke-width*\="2" *d*\="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" /\>  
             \</svg\>  
           \</div\>  
         \<% else %\>  
           \<img *src*\={avatar\_url} *class*\="w-10 h-10 rounded-full object-cover shrink-0" /\>  
         \<% end %\>

         \<\!-- Sidebar Text (Hidden on small mobile screens) \--\>  
         \<div *class*\="overflow-hidden hidden md:block"\>  
           \<p *class*\="font-semibold text-gray-900 dark:text-gray-100 truncate"\>\<%= display\_name %\>\</p\>  
           \<p *class*\="text-xs text-gray-500 dark:text-gray-400 truncate capitalize"\>  
             \<%= conv.type %\>  
           \</p\>  
         \</div\>  
       \</.link\>  
     \<% end %\>  
   \</div\>  
 \</div\>

 \<\!-- RIGHT MAIN: Chat Area \--\>  
 \<div *class*\="flex-1 flex flex-col relative min-w-0"\>  
    
   \<%= if @conversation do %\>  
     \<\!-- Active Chat Header \--\>  
     \<div *class*\="p-4 border-b border-gray-200 dark:border-zinc-800 flex items-center gap-3 bg-white dark:bg-zinc-900 z-10 shadow-sm"\>  
       \<\!-- Back Button (Mobile Only) \--\>  
       \<div *class*\="md:hidden"\>  
         \<.link navigate\={\~p"/feed"} class\="text-gray-500"\>\<svg *class*\="w-6 h-6" *fill*\="none" *stroke*\="currentColor" *viewBox*\="0 0 24 24"\>\<path *stroke-linecap*\="round" *stroke-linejoin*\="round" *stroke-width*\="2" *d*\="M15 19l-7-7 7-7" /\>\</svg\>\</.link\>  
       \</div\>  
        
       \<%  
          \# Header Info Logic  
          is\_group \= @conversation.type *\==* "group"  
          header\_member \= Enum.find(@conversation.conversation\_members, &(&1.user.id \!\= @current\_user.id))  
           
          header\_name \= if is\_group, do: @conversation.name, else: (header\_member && header\_member.user.username)  
          header\_avatar \= if is\_group, do: nil, else: (header\_member && header\_member.user.avatar\_url) || "/images/default\_avatar.png"  
       %\>  
        
       \<\!-- Header Avatar \--\>  
       \<%= if is\_group do %\>  
         \<div *class*\="w-8 h-8 rounded-full bg-blue-100 dark:bg-blue-900 flex items-center justify-center text-blue-600 dark:text-blue-300"\>  
            \<svg *xmlns*\="http://www.w3.org/2000/svg" *class*\="w-5 h-5" *fill*\="none" *viewBox*\="0 0 24 24" *stroke*\="currentColor"\>\<path *stroke-linecap*\="round" *stroke-linejoin*\="round" *stroke-width*\="2" *d*\="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" /\>\</svg\>  
         \</div\>  
       \<% else %\>  
         \<img *src*\={header\_avatar} *class*\="w-8 h-8 rounded-full object-cover" /\>  
       \<% end %\>  
        
       \<span *class*\="font-bold text-gray-900 dark:text-gray-100"\>\<%= header\_name %\>\</span\>  
     \</div\>

     \<\!-- Messages List (Scrollable) \--\>  
     \<div  
       *id*\={*"chat-container-\#{@conversation.id}"}*  
       *class*\="flex-1 overflow-y-auto p-4 space-y-4 bg-white dark:bg-zinc-900"  
       phx-hook\="ChatHook"  
       *data-conversation-id*\={@conversation.id}  
       phx-update\="ignore"  
     \>  
       \<div *id*\="messages" phx-update\="stream" *class*\="flex flex-col space-y-2" phx-hook\="ScrollToBottom"\>  
         \<%= for {dom\_id, message} \<- @streams.messages do %\>  
           \<%  
              \# This Check determines Left vs Right alignment  
              is\_me \= message.user\_id *\==* @current\_user.id  
           %\>  
            
           \<div *id*\={dom\_id} *class*\={*"flex* *w-full* *"* *\<*\> if(is\_me, do: "justify-end", else: "justify-start")}\>  
             \<div *class*\={*"max-w-\[75%\]* *px-4* *py-2* *rounded-2xl* *shadow-sm* *text-sm* *break-words* *"* *\<*\>  
               if(is\_me,  
                 do: "bg-blue-500 text-white rounded-br-none",  
                 else: "bg-gray-100 dark:bg-zinc-800 text-gray-800 dark:text-gray-200 rounded-bl-none")  
             }\>  
               \<p\>\<%= message.content %\>\</p\>  
               \<p *class*\={*"text-\[10px\]* *mt-1* *text-right* *"* *\<*\> if(is\_me, do: "text-blue-100", else: "text-gray-500")}\>  
                 \<%= Timex.format\!(message.inserted\_at, "%H:%M", :strftime) %\>  
               \</p\>  
             \</div\>  
           \</div\>  
         \<% end %\>  
       \</div\>  
     \</div\>

     \<\!-- Input Footer \--\>  
     \<div *class*\="p-4 bg-white dark:bg-zinc-900 border-t border-gray-200 dark:border-zinc-800"\>  
       \<\!-- IMPORTANT: phx-change="validate" ensures the form resets correctly \--\>  
       \<.form for={@form} phx-change\="validate" phx-submit\="send\_message" class\="flex gap-2"\>  
         \<input  
           *type*\="text"  
           *name*\="message\[content\]"  
           *value*\={@form\[:content\].value}  
           *placeholder*\="Type a message..."  
           *autocomplete*\="off"  
           *class*\="flex-1 rounded-full border-gray-300 dark:border-zinc-700 dark:bg-zinc-800 dark:text-white focus:ring-blue-500 focus:border-blue-500 shadow-sm"  
         /\>  
         \<button *type*\="submit" *class*\="bg-blue-500 hover:bg-blue-600 text-white p-3 rounded-full shadow-md transition-transform hover:scale-105"\>  
           \<svg *xmlns*\="http://www.w3.org/2000/svg" *class*\="h-5 w-5" *viewBox*\="0 0 20 20" *fill*\="currentColor"\>  
             \<path *d*\="M10.894 2.553a1 1 0 00-1.788 0l-7 14a1 1 0 001.169 1.409l5-1.429A1 1 0 009 15.571V11a1 1 0 112 0v4.571a1 1 0 00.725.962l5 1.428a1 1 0 001.17-1.408l-7-14z" /\>  
           \</svg\>  
         \</button\>  
       \</.form\>  
     \</div\>  
    
   \<% else %\>  
     \<\!-- Empty State (No Conversation Selected) \--\>  
     \<div *class*\="flex-1 flex items-center justify-center text-gray-400 dark:text-gray-500 bg-white dark:bg-zinc-900"\>  
       \<div *class*\="text-center"\>  
         \<svg *class*\="w-16 h-16 mx-auto mb-4 opacity-50" *fill*\="none" *stroke*\="currentColor" *viewBox*\="0 0 24 24"\>\<path *stroke-linecap*\="round" *stroke-linejoin*\="round" *stroke-width*\="1.5" *d*\="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" /\>\</svg\>  
         \<p *class*\="text-lg"\>Select a conversation to start chatting\</p\>  
       \</div\>  
     \</div\>  
   \<% end %\>

 \</div\>  
\</div\>  
