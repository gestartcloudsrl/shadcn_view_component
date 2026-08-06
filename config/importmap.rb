# Importmap pins contributed by the engine to the host application.
pin "shadcn", to: "shadcn/index.js"

pin_all_from ShadcnViewComponent::Engine.root.join("app/javascript/shadcn"),
             under: "shadcn",
             to: "shadcn"
