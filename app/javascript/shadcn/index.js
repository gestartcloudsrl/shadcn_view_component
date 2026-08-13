// Entry point for the Stimulus controllers that reproduce the Radix UI
// behaviour of the interactive components.
//
//   import { Application } from "@hotwired/stimulus"
//   import { registerShadcnControllers } from "shadcn"
//
//   registerShadcnControllers(Application.start())
//
// Controllers register under the `shadcn--` prefix, which is what the
// components emit: `data-controller="shadcn--accordion"`.

import AccordionController from "shadcn/controllers/accordion_controller"
import AvatarController from "shadcn/controllers/avatar_controller"
import CalendarController from "shadcn/controllers/calendar_controller"
import CarouselController from "shadcn/controllers/carousel_controller"
import CheckboxController from "shadcn/controllers/checkbox_controller"
import CollapsibleController from "shadcn/controllers/collapsible_controller"
import DialogController from "shadcn/controllers/dialog_controller"
import DrawerController from "shadcn/controllers/drawer_controller"
import DropdownMenuController from "shadcn/controllers/dropdown_menu_controller"
import HoverCardController from "shadcn/controllers/hover_card_controller"
import InputGroupController from "shadcn/controllers/input_group_controller"
import InputOtpController from "shadcn/controllers/input_otp_controller"
import MenubarController from "shadcn/controllers/menubar_controller"
import MessageScrollerController from "shadcn/controllers/message_scroller_controller"
import NavigationMenuController from "shadcn/controllers/navigation_menu_controller"
import PopoverController from "shadcn/controllers/popover_controller"
import RadioGroupController from "shadcn/controllers/radio_group_controller"
import ScrollAreaController from "shadcn/controllers/scroll_area_controller"
import SelectController from "shadcn/controllers/select_controller"
import SidebarController from "shadcn/controllers/sidebar_controller"
import SliderController from "shadcn/controllers/slider_controller"
import SwitchController from "shadcn/controllers/switch_controller"
import TabsController from "shadcn/controllers/tabs_controller"
import ToasterController from "shadcn/controllers/toaster_controller"
import ThemeController from "shadcn/controllers/theme_controller"
import ToggleController from "shadcn/controllers/toggle_controller"
import ToggleGroupController from "shadcn/controllers/toggle_group_controller"
import TooltipController from "shadcn/controllers/tooltip_controller"

const CONTROLLERS = {
  accordion: AccordionController,
  avatar: AvatarController,
  calendar: CalendarController,
  carousel: CarouselController,
  checkbox: CheckboxController,
  collapsible: CollapsibleController,
  dialog: DialogController,
  drawer: DrawerController,
  "dropdown-menu": DropdownMenuController,
  "hover-card": HoverCardController,
  "input-group": InputGroupController,
  "input-otp": InputOtpController,
  menubar: MenubarController,
  "message-scroller": MessageScrollerController,
  "navigation-menu": NavigationMenuController,
  popover: PopoverController,
  "radio-group": RadioGroupController,
  "scroll-area": ScrollAreaController,
  select: SelectController,
  sidebar: SidebarController,
  slider: SliderController,
  switch: SwitchController,
  tabs: TabsController,
  theme: ThemeController,
  toggle: ToggleController,
  "toggle-group": ToggleGroupController,
  toaster: ToasterController,
  tooltip: TooltipController
}

export function registerShadcnControllers(application) {
  for (const [ name, controller ] of Object.entries(CONTROLLERS)) {
    application.register(`shadcn--${name}`, controller)
  }

  resyncOnMorph(application)

  return application
}

// A Turbo morph refresh rewrites attributes in place without disconnecting the
// controllers, so `connect()` never runs again: the DOM goes back to whatever
// the server rendered while the controller still holds the old ids, targets and
// state. Re-running `render()` puts the two back in agreement.
//
// The server's state wins, which is what a refresh means. To keep a component's
// open state across a morph, mark it `data-turbo-permanent` in your own markup —
// that is the application's call, not the library's.
function resyncOnMorph(application) {
  if (typeof document === "undefined") return

  document.addEventListener("turbo:morph", () => {
    for (const controller of application.controllers) {
      if (!controller.identifier.startsWith("shadcn--")) continue
      if (typeof controller.render === "function") controller.render()
    }
  })
}

export { CONTROLLERS }
export default registerShadcnControllers
