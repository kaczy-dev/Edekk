import { motion, AnimatePresence } from "framer-motion";
import { Link } from "@tanstack/react-router";
import { useState } from "react";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from "@/components/ui/alert-dialog";

interface Props {
  open: boolean;
  onResume: () => void;
  onRestart: () => void;
}

export function PauseMenu({ open, onResume, onRestart }: Props) {
  return (
    <AnimatePresence>
      {open && (
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          className="absolute inset-0 z-50 flex items-center justify-center scrim"
        >
          <motion.div
            initial={{ scale: 0.9, y: 20 }}
            animate={{ scale: 1, y: 0 }}
            exit={{ scale: 0.95, y: 10 }}
            className="w-80 panel-glass p-6 text-center shadow-2xl"
          >
            <h3 className="font-display text-3xl font-semibold text-honey">Pauza</h3>
            <p className="mt-1 text-sm text-muted-foreground">Edek czeka spokojnie.</p>
            <div className="mt-5 flex flex-col gap-2">
              <button
                onClick={onResume}
                className="rounded-xl bg-primary px-4 py-2.5 font-semibold text-primary-foreground transition hover:opacity-90"
              >
                Wróć do gry
              </button>
              <AlertDialog>
                <AlertDialogTrigger className="rounded-xl border border-border bg-secondary px-4 py-2 text-sm font-medium text-secondary-foreground transition hover:bg-muted">
                  Zacznij poziom od nowa
                </AlertDialogTrigger>
                <AlertDialogContent>
                  <AlertDialogHeader>
                    <AlertDialogTitle>Zacząć od nowa?</AlertDialogTitle>
                    <AlertDialogDescription>Stracisz postęp w tym poziomie.</AlertDialogDescription>
                  </AlertDialogHeader>
                  <AlertDialogFooter>
                    <AlertDialogCancel>Anuluj</AlertDialogCancel>
                    <AlertDialogAction onClick={onRestart}>Tak, zacznij od nowa</AlertDialogAction>
                  </AlertDialogFooter>
                </AlertDialogContent>
              </AlertDialog>
              <Link
                to="/menu"
                className="rounded-xl px-4 py-2 text-sm text-muted-foreground transition hover:text-foreground"
              >
                Wyjdź do menu
              </Link>
            </div>
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
