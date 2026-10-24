import {
  ChangeDetectionStrategy,
  Component,
  computed,
  effect,
  ElementRef,
  inject,
  input,
  Renderer2,
  viewChild,
} from '@angular/core';
import { IconRegistry, type IconNode } from './icon-registry';

const SVG_NS = 'http://www.w3.org/2000/svg';
const IGNORED_ATTRS = new Set(['key']);
const toKebab = (attr: string) => attr.replace(/[A-Z]/g, (char) => `-${char.toLowerCase()}`);

@Component({
  selector: 'ui-icon',
  changeDetection: ChangeDetectionStrategy.OnPush,
  host: {
    class: 'ui-icon',
    'aria-hidden': 'true',
    '[style.width.px]': 'size()',
    '[style.height.px]': 'size()',
  },
  template: `<svg
    #svg
    viewBox="0 0 24 24"
    fill="none"
    [attr.width]="size()"
    [attr.height]="size()"
  ></svg>`,
  styles: `
    :host {
      display: inline-flex;
      flex: none;
      align-items: center;
      justify-content: center;
      line-height: 0;
    }

    svg {
      flex: none;
    }
  `,
})
export class UiIcon {
  private readonly registry = inject(IconRegistry);
  private readonly renderer = inject(Renderer2);
  private readonly svg = viewChild.required<ElementRef<SVGSVGElement>>('svg');

  readonly name = input.required<string>();
  readonly size = input(18);
  readonly strokeWidth = input(1.5);

  protected readonly node = computed<IconNode>(
    () => (this.registry.get(this.name()) ?? this.registry.get('circle'))?.node ?? [],
  );

  constructor() {
    effect(() => this.draw(this.svg().nativeElement, this.node(), this.strokeWidth()));
  }

  private draw(svg: SVGSVGElement, node: IconNode, strokeWidth: number): void {
    svg.replaceChildren();
    for (const [tag, attrs] of node) {
      const element = this.renderer.createElement(tag, SVG_NS) as SVGElement;
      for (const [attr, value] of Object.entries(attrs)) {
        if (!IGNORED_ATTRS.has(attr)) {
          this.renderer.setAttribute(
            element,
            toKebab(attr),
            String(attr === 'strokeWidth' ? strokeWidth : value),
          );
        }
      }
      this.renderer.appendChild(svg, element);
    }
  }
}
